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

"""
	bind(xyz, PlutoUI.Slider([1,2,3]))

Bind a UserInput to a variable from R. Note that the first argument needs
to be a variable name - it will be assigned inside bind.
"""
function JolinPluto.bindr(name, ui)
	if !isdefined(Main, :PlutoRunner)
		# no Pluto system is running
		initial_value_getter = try
			Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value
		catch
			b -> missing
		end
		initial_value = Core.applicable(Base.get, ui) ? Base.get(ui) : initial_value_getter(ui)
		RCall.Const.GlobalEnv[name] = initial_value
		return ui
	else
		def = Symbol(RCall.rcopy(name))
		initial_value = Core.applicable(Base.get, ui) ? Base.get(ui) : Main.PlutoRunner.initial_value_getter_ref[](ui)
		RCall.Const.GlobalEnv[def] = initial_value
		return Main.PlutoRunner.create_bond(ui, def, Main.PlutoRunner.currently_running_cell_id.x)
	end	
end

function __init__()
	# extra helpers
	# for all extra helpers to work, apparently juliacall needs to be loaded
	# not sure why precisely, TODO inspect further
	RCall.reval("library(JuliaCall); julia_setup(installJulia=TRUE)")

	RCall.Const.GlobalEnv[:format_html] = format_html
	# Markdown and HTML support should be there out of the box
	# CommonMark is used, because the standard Markdown does not support html strings inside markdown string.
	# (within Julia itself the object interpolation works, because everything is stored as julia objects and only finally transformed to html.)

	"""
		HTML("<h1> HTML String </h1>")
	"""
	function _HTML(args...; kwargs...)
		HTML(args...; kwargs...)
	end
	# RCall does not support arbitrary types, but is good with functions
	RCall.Const.GlobalEnv[:MD] = MD
	RCall.Const.GlobalEnv[:HTML] = _HTML

	RCall.Const.GlobalEnv[Symbol(".bind")] = JolinPluto.bindr
	RCall.reval("bind <- function(var, ui) .bind(sys.call()[[2]], ui)")
	@info "R setup done"
end


end # module