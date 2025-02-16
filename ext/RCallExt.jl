module RCallExt
import RCall
import JolinPluto
using TestItems

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

JolinPluto.lang_enabled(::Val{:r}) = true
function JolinPluto.lang_set_global(::Val{:r}, def::Symbol, value)
	RCall.Const.GlobalEnv[def] = value
end
function JolinPluto.lang_get_global(::Val{:r}, def::Symbol)
	RCall.Const.GlobalEnv[def]
end

@testitem "RCall globals" begin
	# set a valid R installation for CondaPkg in case it does not exist yet
	
	# This is actually quite nice, as usually we would first need to add R as a dependency in order to use Preferences on it.
	# As RCall is a dependency of this project, we can dynamically create preferences which make sure we always have a valid R installation
	# before triggering the automatic recompilation with `import RCall`.

	using Preferences
	using UUIDs
	const RCALL_UUID = UUID("6f49c342-dc21-5d91-9882-a32aef131414")
	if load_preference(RCALL_UUID, "Rhome") === nothing
		using Libdl
		using CondaPkg

		CondaPkg.add("r")
		target_rhome = joinpath(CondaPkg.envdir(), "lib", "R")
		if Sys.iswindows()
			target_libr = joinpath(target_rhome, "bin", Sys.WORD_SIZE==64 ? "x64" : "i386", "R.dll")
		else
			target_libr = joinpath(target_rhome, "lib", "libR.$(Libdl.dlext)")
		end
		set_preferences!(RCALL_UUID, "Rhome" => target_rhome, "libR" => target_libr)
	end

    import RCall
    JolinPluto.lang_set_global(Val(:r), :x, 42)
    @test 42 == RCall.@rget(x) == RCall.rcopy(JolinPluto.lang_get_global(Val(:r), :x))
end

end # module