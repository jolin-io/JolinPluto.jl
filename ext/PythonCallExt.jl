module PythonCallExt

import JolinPluto
using PythonCall
using HypertextLiteral
import AbstractPlutoDingetjes

function JolinPluto.repeat_queueget(q)
    function _repeat_queueget()
        while PythonCall.pytruth(q.empty())
            sleep(0.0)
        end
        # this is guaranteed to work as long as there is only a single repeat_queueget on a queue
        q.get_nowait()
    end
    JolinPluto.repeat_run(_repeat_queueget)
end

function JolinPluto.start_python_thread(func)
    threading = @pyconst(pyimport("threading"))

    if !JolinPluto.is_running_in_jolinpluto_process()
        # just start a plain thread without cleanup
        stop_event = threading.Event()
        threading.Thread(target=func, daemon=true, args=(stop_event,)).start()
        return stop_event
    end

	firsttime = Main.PlutoRunner.currently_running_user_requested_run[]
	cell_id = Main.PlutoRunner.currently_running_cell_id[]

    if firsttime
        stop_event_ref = Ref{Any}()
        function cleanup_func()
            isassigned(stop_event_ref) && stop_event_ref[].set()
            nothing
        end
        Main.PlutoRunner.UseEffectCleanups.register_cleanup(cleanup_func, cell_id)
        Main.PlutoRunner.UseEffectCleanups.register_cleanup(cell_id) do
			haskey(JolinPluto.pluto_cell_cache, cell_id) && delete!(JolinPluto.pluto_cell_cache, cell_id)
		end

        function _start_python_thread(func)
			# NOTE: no need to do exception handling as channel exceptions are thrown on take!
			# if cell is reloaded we stop the underlying process so that the previous Channel
			# can be garbage collected
			cleanup_func()
            stop_event_ref[] = threading.Event()
			threading.Thread(target=func, args=(stop_event_ref[],)).start()
            return stop_event_ref[]
		end
        JolinPluto.pluto_cell_cache[cell_id] = _start_python_thread
        _start_python_thread(func)
    else
        JolinPluto.pluto_cell_cache[cell_id](func)
    end
end


pyglobals() = get!(PythonCall.pydict, PythonCall.Core.MODULE_GLOBALS, Main)

JolinPluto.lang_enabled(::Val{:py}) = true
function JolinPluto.lang_set_global(::Val{:py}, def, value)
    pyglobals()[string(def)] = value
end
function JolinPluto.lang_get_global(::Val{:py}, def)
    pyglobals()[string(def)]
end



# ipywidgets support
# ==================

# global initialization needed for ipywidgets
"""
    IPyWidget_init()

Initialize javascript for ipywidgets to work inside Pluto.
"""
JolinPluto.IPyWidget_init() = @htl """
<!-- Load RequireJS, used by the IPywidgets for dependency management -->
<script
  src="https://cdnjs.cloudflare.com/ajax/libs/require.js/2.3.4/require.min.js"
  integrity="sha256-Ae2Vz/4ePdIu6ZyI/5ZGsYnb+m0JlOmKPjt6XZ9JJkA="
  crossorigin="anonymous">
</script>

<!-- Load IPywidgets bundle for embedding. -->
<script
  data-jupyter-widgets-cdn="https://unpkg.com/"
  data-jupyter-widgets-cdn-only
  src="https://cdn.jsdelivr.net/npm/@jupyter-widgets/html-manager@*/dist/embed-amd.js"
  crossorigin="anonymous">
</script>

<script>
(()=>{
	"use strict";
	window.require(["@jupyter-widgets/base"], (function(b) {
		b.WidgetView.prototype.touch = function(){
			let div = this.el.closest('div[type="application/vnd.jupyter.widget-view+div"]')
			if (this.model._buffered_state_diff?.value != null){
				div.value = this.model._buffered_state_diff.value 
				div.dispatchEvent(new CustomEvent('input'))
			}
		}
	}))
})();
</script>
"""

# Defined in JolinPluto
# """ Wrap an ipywidget to be used in Pluto """
# struct IPyWidget
#     wi
# end

function Base.show(io::IO, m::MIME"text/html", w::JolinPluto.IPyWidget)
    e = PythonCall.pyimport("ipywidgets.embed")
    data = e.embed_data(views=[w.wi], state=e.dependency_state([w.wi]))
    show(io, m, @htl """
    <div type="application/vnd.jupyter.widget-view+div">
    <script>
    (()=>{
        "use strict";
        const div = currentScript.parentElement;
        // this is key so that the initial value won't be set to nothing immediately
        // this value property will be read out for the client-site initial value
        div.value = $(pyconvert(Any, w.wi.value))

        // TODO renderWidgets(div) has the advantage that no duplicates appear
        // however if the same ui is used multiple times on the website, they also won't be combined any longer into one synced state (which actually happens automatically without the div restriction)
        // still for now having no duplicates (why ever they appear without the div restriction) is better than no sync
        window.require(["@jupyter-widgets/html-manager/dist/libembed-amd"], (function(e) {
            // without this the second execution wouldn't show anything 
            "complete" === document.readyState ? e.renderWidgets(div) : window.addEventListener("load", (function() {
                e.renderWidgets(div)
            }))
        }))
    })();
    </script>
    
    <!-- The state of all the widget models on the page -->
    <script type="application/vnd.jupyter.widget-state+json">
          $(pyconvert(Dict, data["manager_state"]))
    </script>
    <!-- This script tag will be replaced by the view's DOM tree -->
    <script type="application/vnd.jupyter.widget-view+json">
        $(pyconvert(Dict, data["view_specs"][0]))
    </script>

    <script>
    invalidation.then(() => {
        // cleanup here!
    })
    </script>
    </div>
    """)
end

function AbstractPlutoDingetjes.Bonds.initial_value(w::JolinPluto.IPyWidget)
    return pyconvert(Any, w.wi.value)
end

function pyshow_rule_ipywidgets(io::IO, mime::String, x::Py)
    pyissubclass(pytype(x), @pyconst(pyimport("ipywidgets").widgets.ValueWidget)) || return false
    try
        show(io, mime, JolinPluto.IPyWidget(x))
        return true
    catch exc
        if exc isa PyException
            return false
        else
            rethrow()
        end
    end
end

function __init__()
    # improve support for ipywidgets
    if isdefined(PythonCall, :Compat)  # older versions of PythonCall don't have the Compat submodule
        PythonCall.Compat.pyshow_add_rule(pyshow_rule_ipywidgets)
    end
    # improve support for plotly figures
    if isdefined(PythonCall, :Convert)  # older versions of PythonCall don't have the Convert submodule
        PythonCall.Convert.pyconvert_add_rule("plotly.graph_objs._figure:Figure", PythonCall.Py, PythonCall.Convert.pyconvert_rule_object, PythonCall.Convert.PYCONVERT_PRIORITY_WRAP)
    end
end

end