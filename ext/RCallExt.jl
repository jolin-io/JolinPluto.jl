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

end # module