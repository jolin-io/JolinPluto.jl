"""
	is_running_in_pluto_process()

This doesn't mean we're in a Pluto cell, e.g. can use @bind and hooks goodies.
It only means PlutoRunner is available (and at a version that technically supports hooks)
"""
function is_running_in_pluto_process()
	isdefined(Main, :PlutoRunner) &&
	# Also making sure my favorite goodies are present
	isdefined(Main.PlutoRunner, :GiveMeCellID) &&
	isdefined(Main.PlutoRunner, :GiveMeRerunCellFunction) &&
	isdefined(Main.PlutoRunner, :GiveMeRegisterCleanupFunction)
end

"""
	is_running_in_pluto_process()

This doesn't mean we're in a Pluto cell, e.g. can use @bind and hooks goodies.
It only means PlutoRunner is available (and at a version that technically supports hooks)
"""
function is_running_in_jolinpluto_process()
	ispluto = is_running_in_pluto_process()
	isjolin = ispluto && isdefined(Main.PlutoRunner, :currently_running_user_requested_run)

	if ispluto && !isjolin
		@warn "You are using functionality which is as of now only available inside Jolin's reactive notebooks. Falling back to no reactivity."  
	end
	return ispluto && isjolin
end
