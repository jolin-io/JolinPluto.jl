module RCallExt
import CondaPkg  # only needed for initialization
import RCall, JolinPluto

function JolinPluto.ChannelWithRepeatedFill(get_next_value::RCall.RObject, args...; sleep_seconds=0.0, skip_value=JolinPluto.NoPut, kwargs...)
	JolinPluto.ChannelPluto(args...; kwargs...) do ch
		_skip_value = RCall.rcopy(skip_value)
        while true
			value = RCall.rcopy(get_next_value())
			value != _skip_value && put!(ch, value)
			sleep(sleep_seconds)
		end
	end
end

# c(MD, HTML, format_html, viewof) %<-% julia_eval("Jolin.MD, Jolin._HTML, Jolin.format_html, Jolin.viewof")

JolinPluto.lang_enabled(::Val{:r}) = true
function JolinPluto.lang_copy_bind(::Val{:r}, def::Symbol, value)
	RCall.Const.GlobalEnv[def] = value
end

function __init__()
	# this is crucial so that the path is set correctly
    # while PythonCall does this by itself, RCall needs this manual help, 
    # which effects both plain Julia with RCall as well as PlutoR
    CondaPkg.activate!(ENV)
end

end # module