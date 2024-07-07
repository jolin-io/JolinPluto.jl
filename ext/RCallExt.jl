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


# RCall's calling syntax does not support arbitrary types, but is good with functions
"""
	HTML("<h1> HTML String </h1>")
"""
function _HTML(args...; kwargs...)
	HTML(args...; kwargs...)
end

const _r_module_where_plutoscript_is_included = Ref{RCall.RObject{RCall.EnvSxp}}()

function JolinPluto.init_jolin(r_environment::RCall.RObject{RCall.EnvSxp})
    _r_module_where_plutoscript_is_included[] = r_environment

	r_environment[:format_html] = JolinPluto.format_html
	# Markdown and HTML support should be there out of the box
	# CommonMark is used, because the standard Markdown does not support html strings inside markdown string.
	# (within Julia itself the object interpolation works, because everything is stored as julia objects and only finally transformed to html.)
	r_environment[:MD] = JolinPluto.MD
	r_environment[:HTML] = _HTML

	r_environment[Symbol(".bind")] = JolinPluto.bind
	RCall.reval("bind <- function(var, ui) .bind(sys.call()[[2]], ui)", r_environment)
	nothing
end

JolinPluto.lang_enabled(::Val{:r}) = true
function JolinPluto.lang_copy_bind(::Val{:r}, def, value)
	RCall.Const.GlobalEnv[def] = value
end


function __init__()
	_r_module_where_plutoscript_is_included[] = RCall.Const.GlobalEnv
end


end # module