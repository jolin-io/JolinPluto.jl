# Core Setter implementation
# --------------------------

"""
    Setter()
    Setter("initial_value")

Creates a pluto interactivity which separates the setter cell from the state cell.

# Usage

```julia
set_a = Setter("initial_value")

# in another cell, extract the inner state from the setter
# such that updates will rerun this cell
a = @get set_a

# in yet another cell use `set_a`
set_a("new_value")

# or use a function syntax to easily access the previous value
set_a() do prev_a
    "\$prev_a!!"
end
```
"""
mutable struct Setter{T}
	value::T
	just_created::Bool
	rerun::Union{Nothing, Function}
	Setter() = new{Any}(nothing, true, nothing)
	Setter(initial_value::T) where T = new{T}(initial_value, true, nothing)
	Setter{T}(initial_value) where T = new{T}(initial_value, true, nothing)
end

function (setter::Setter)(value)
	# this little boolean distinguishes normal reexecution (recreation) from rerun execution.
	setter.just_created = false
	setter.value = value
	setter.rerun !== nothing && setter.rerun()
	nothing
end

function (setter::Setter)(func::Function)
	# this little boolean distinguishes normal reexecution (recreation) from rerun execution.
	setter.just_created = false
	setter.value = func(setter.value)
	setter.rerun !== nothing && setter.rerun()
	nothing
end

# traits support by default
getsetter(setter::Setter) = setter


macro get(setter)
	setter = esc(setter)
	firsttime = Ref(true)
	is_running_in_pluto_process() || return :($setter.value)
	quote
		setter = getsetter($setter)
		if $firsttime[] || setter.just_created
			rerun = $(Main.PlutoRunner.GiveMeRerunCellFunction())
			if setter.rerun !== nothing
				@error "`@get` was already called on the setter. Only use one invocation of `@get` per setter."
			end
			setter.rerun = rerun

            if $firsttime[]
                $firsttime[] = false
                cleanup = $(Main.PlutoRunner.GiveMeRegisterCleanupFunction())
                cleanup() do
                    if setter.rerun === rerun
                        setter.rerun = nothing
                    end
                end
            end
        end
		setter.value
	end
end



function Base.get(setter::Setter)
	is_running_in_jolinpluto_process() || return setter.value
	firsttime = Main.PlutoRunner.currently_running_user_requested_run[]

	if firsttime || setter.just_created
		cell_id = Main.PlutoRunner.currently_running_cell_id[]
		if setter.rerun !== nothing
			@error "`get` was already called on the setter. Only use one invocation of `get` per setter."
		end
		rerun = () -> Main.PlutoRunner.rerun_cell_from_notebook(cell_id)
		setter.rerun = rerun
		if firsttime
			Main.PlutoRunner.UseEffectCleanups.register_cleanup(cell_id) do
				if setter.rerun === rerun
					setter.rerun = nothing
				end
			end
		end
	else
		setter.value
	end
end


# Concrete Application - Collecting Cellids behind the Scenes
# --------------------

"""
    cell_ids_wrapper = @cell_ids_create_wrapper()

Creates a wrapper around a Set of cell_ids so that they can be added (and removed)
seamlessly and automatically from other cells.

# Usage
```julia
cell_ids_wrapper = @cell_ids_create_wrapper()

# in another cell access the cellids and e.g. print the url suffix
cell_ids = @get cell_ids_wrapper
print(join("&isolated_cell_id=\$id" for id in cell_ids))

# in yet another cell add its cell_id
@cell_ids_push! cell_ids_wrapper
```
"""
macro cell_ids_create_wrapper()
	QuoteNode(Setter(Set()))
end


"""
    cell_ids_wrapper = cell_ids_create_wrapper()

Creates a wrapper around a Set of cell_ids so that they can be added (and removed)
seamlessly and automatically from other cells.

# Usage
```julia
cell_ids_wrapper = cell_ids_create_wrapper()

# in another cell access the cellids and e.g. print the url suffix
cell_ids = get(cell_ids_wrapper)
print(join("&isolated_cell_id=\$id" for id in cell_ids))

# in yet another cell add its cell_id
cell_ids_push!(cell_ids_wrapper)
```
"""
cell_ids_create_wrapper() = Setter(Set())


"""
    @cell_ids_push! cell_ids_wrapper

Adds the cell's cell-id to the given cell_ids_wrapper.
This automatically handles retriggering of cells as needed.

Also cleanup is handled, i.e. that the cell-id is removed again if this cell is deleted.
"""
macro cell_ids_push!(setter)
	setter = esc(setter)
	# if this is not run inside Pluto, we just don't add a cell_id
	is_running_in_pluto_process() || return QuoteNode(nothing)
	quote
		setter = getsetter($setter)
		cell_id = $(Main.PlutoRunner.GiveMeCellID())
		setter() do cell_ids
			push!(cell_ids, cell_id)
		end
		cleanup = $(Main.PlutoRunner.GiveMeRegisterCleanupFunction())
		cleanup() do
			setter() do cell_ids
				delete!(cell_ids, cell_id)
			end
		end
		nothing
	end
end


"""
    cell_ids_push!(cell_ids_wrapper)

Adds the cell's cell-id to the given cell_ids_wrapper.
This automatically handles retriggering of cells as needed.

Also cleanup is handled, i.e. that the cell-id is removed again if this cell is deleted.
"""
function cell_ids_push!(setter::Setter)
	# if this is not run inside Pluto, we just don't add a cell_id
	is_running_in_jolinpluto_process() || return nothing

	firsttime = Main.PlutoRunner.currently_running_user_requested_run[]
	cell_id = Main.PlutoRunner.currently_running_cell_id[]

	if firsttime
		Main.PlutoRunner.UseEffectCleanups.register_cleanup(cell_id) do
			setter() do cell_ids
				delete!(cell_ids, cell_id)
			end
		end
	end

	setter() do cell_ids
		push!(cell_ids, cell_id)
	end
	nothing
end

# useful for use in Python and R, where exclamation mark is not a valid symbol
const cell_ids_push = cell_ids_push!