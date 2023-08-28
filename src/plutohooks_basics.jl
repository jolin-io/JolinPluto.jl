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


Base.@kwdef struct NotRunningInPlutoCellException <: Exception end

function Base.showerror(io::IO, expr::NotRunningInPlutoCellException)
	print(io, "NotRunningInPlutoCell: Expected to run in a Pluto cell, but wasn't! We'll try to get these hooks to work transparently when switching from Pluto to a script.. but not yet, so just as a precaution: this error!")
end



"""
	@give_me_the_pluto_cell_id()

> ⚠️ Don't use this directly!! if you think you need it, you might actually need [`@use_did_deps_change([])`](@ref) but even that is unlikely.

Used inside a Pluto cell this will resolve to the current cell UUID.
Outside a Pluto cell it will throw an error.
"""
macro give_me_the_pluto_cell_id()
	if is_running_in_pluto_process()
		:($(Main.PlutoRunner.GiveMeCellID()))
	else
		:(throw(NotRunningInPlutoCellException()))
	end
end


"""
	@give_me_rerun_cell_function()

> ⚠️ Don't use this directly!! if you think you need it, you need [`@use_state`](@ref).

Used inside a Pluto cell this will resolve to a function that, when called, will cause the cell to be re-run (in turn re-running all dependent cells).
Outside a Pluto cell it will throw an error.
"""
macro give_me_rerun_cell_function()
	if is_running_in_pluto_process()
		:($(Main.PlutoRunner.GiveMeRerunCellFunction()))
	else
		:(throw(NotRunningInPlutoCellException()))
	end
end

# ╔═╡ cf55239c-526b-48fe-933e-9e8d56161fd6
"""
	@give_me_register_cleanup_function()

> ⚠️ Don't use this directly!! if you think you need it, you need [`@use_effect`](@ref).

Used inside a Pluto cell this will resolve to a function that call be called with yet another function, and then will call that function when the cell gets explicitly re-run. ("Explicitly re-run" meaning all `@use_ref`s get cleared, for example).
Outside a Pluto cell it will throw an error.
"""
macro give_me_register_cleanup_function()
	if is_running_in_pluto_process()
		:($(Main.PlutoRunner.GiveMeRegisterCleanupFunction()))
	else
		:(throw(NotRunningInPlutoCellException()))
	end
end