module PythonExt

import JolinPluto
using PythonCall

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

    if !JolinPluto.is_running_in_pluto_process()
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



const _python_module_where_plutoscript_is_included = Ref{PyDict}()

JolinPluto.init_jolin(python_globals::Py) = JolinPluto.init_jolin(pyconvert(PyDict, python_globals))
function JolinPluto.init_jolin(python_globals::PyDict)
    _python_module_where_plutoscript_is_included[] = python_globals
    nothing
end

JolinPluto.lang_enabled(::Val{:py}) = true
function JolinPluto.lang_copy_bind(::Val{:py}, def, value)
    _python_module_where_plutoscript_is_included[][String(def)] = value
end

function __init__()
    # this is not calling jolin_init, as jolin_init may extend to do further things next to initializing the module
    # e.g. in PlutoR it will also set variables
    _python_module_where_plutoscript_is_included[] = pyconvert(PyDict, get!(PythonCall.pydict, PythonCall.Core.MODULE_GLOBALS, Main))
end

# """
#     bindpy("xyz", jl.Slider([1,2,3]))

# Bind a UserInput to a variable from Python. Note that the first argument cannot
# be a variable, but necessarily needs to be a constant string.
# """
# function JolinPluto.bindpy(name, ui)
#     if !isdefined(Main, :PlutoRunner)
#         initial_value_getter = try
#             Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value
#         catch
#             b -> missing
#         end
#         initial_value = Core.applicable(Base.get, ui) ? Base.get(ui) : initial_value_getter(ui)
#         pyglobals[name] = initial_value
#         return ui
#     else
#         def = PythonCall.pyconvert(Symbol, name)
#         initial_value = Core.applicable(Base.get, ui) ? Base.get(ui) : Main.PlutoRunner.initial_value_getter_ref[](ui)
#         pyglobals[name] = initial_value
#         # setglobal!(Main, def, initial_value)
#         return PlutoRunner.create_bond(ui, def, Main.PlutoRunner.currently_running_cell_id[])
#     end
# end

end