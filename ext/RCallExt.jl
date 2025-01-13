module RCallExt
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

# c(MD, HTML, format_html, viewof) %<-% julia_eval("Jolin.MD, s -> HTML(s), Jolin.format_html, Jolin.viewof")

JolinPluto.lang_enabled(::Val{:r}) = true
function JolinPluto.lang_set_global(::Val{:r}, def::Symbol, value)
	RCall.Const.GlobalEnv[def] = value
end
function JolinPluto.lang_get_global(::Val{:r}, def::Symbol)
	RCall.Const.GlobalEnv[def]
end

end # module