# Helpers
# -------

struct SilentlyCancelTask <: Exception end

struct ExceptionFromTask <: Exception
    errstack::Union{Nothing, Base.ExceptionStack}
    errio::String
end

function Base.showerror(io::IO, ex::ExceptionFromTask)
    write(io, ex.errio)
    flush(io)
end

function errormonitor_pluto(set_error, t::Task)
	t2 = Task() do
		if istaskfailed(t)
			local errs = stderr
			sleep(2)
			try # try to display the failure atomically
				errstack = current_exceptions(t)
				if (!isempty(errstack)
					&& isa(errstack[end].exception, SilentlyCancelTask))
					return nothing
				end
				# If take! fails, the exception from within the Channel is wrapped
				# inside a TaskFailedException.
				# We also support this for silent ignore
				if (!isempty(errstack)
					&& isa(errstack[end].exception, TaskFailedException)
					&& isa(current_exceptions(errstack[end].exception.task)[end].exception, SilentlyCancelTask))
					return nothing
				end

				errio = IOContext(PipeBuffer(), errs::IO)
				Base.emphasize(errio, "Unhandled Task ")
				Base.display_error(errio, Base.scrub_repl_backtrace(errstack))
				set_error(ExceptionFromTask(errstack, read(errio, String)))
			catch
				try # try to display the secondary error atomically
					errstack = current_exceptions(t)
					errio = IOContext(PipeBuffer(), errs::IO)

					print(errio, "\nSYSTEM: caught exception while trying to print a failed Task notice: ")
					Base.display_error(errio, Base.scrub_repl_backtrace(current_exceptions()))

					# and then the actual error, as best we can
					print(errio, "\nwhile handling: ")
					println(errio, errstack[end][1])
					set_error(ExceptionFromTask(errstack, read(errio, String)))
				catch e
					# give up
					Core.print(Core.stderr, "\nSYSTEM: caught exception of type ", typeof(e).name.name,
							" while trying to print a failed Task notice; giving up\n")
				end
			end
		end
		nothing
	end
	t2.sticky = false
	Base._wait2(t, t2)
	return t
end


create_taskref_cleanup(taskref, exception=SilentlyCancelTask) = function taskref_cleanup_function()
	isassigned(taskref) || return nothing
	task = taskref[]
	task !== nothing && !istaskdone(task) || return nothing
	try
		Base.schedule(task, exception(), error=true)
	catch error
		nothing
	end
end


# Key macros
# ----------


"""
	@repeat_run(expr_used_for_init_and_repeated_execution)
	@repeat_run(expr_for_init, expr_for_repetition)

Repeat some long expression. It will run offline in a separate Task so that
interactivity is preserved.

Optionally, specify another expression for initialization. Initialization will
also be triggered if the cell is re-evaluated because some dependent cell or bond
changed.
"""
macro repeat_run(init, repeatme=init)
	init = esc(init)
	repeatme = esc(repeatme)

	JolinPluto.is_running_in_pluto_process() || return quote
		$init
	end

	hooked = Ref(false)
	update = Ref{Any}()
	rerun = Ref{Any}()
	task = Ref{Task}()
	function set_update(value)
		hooked[] = true
		update[] = value
		isassigned(rerun) && rerun[]()
		value
	end
	firsttime = Ref(true)
	:(let
		if $firsttime[]
			$rerun[] = $(Main.PlutoRunner.GiveMeRerunCellFunction())
			register_cleanup_fn = $(Main.PlutoRunner.GiveMeRegisterCleanupFunction)
			register_cleanup_fn($(create_taskref_cleanup(task)))
			$firsttime[] = false
		end

		# if triggered by other cell or bond
		if !$hooked[]
			# then we want to cancel the currently running task because it is ill-defined
			$(JolinPluto.create_taskref_cleanup(task))()
			isassigned($task) && Base._wait($task[])  # Base._wait is like wait, but without rethrowing an error
			# only after the task is really finished, start initialization
			$update[] = $init
		else
			# if triggered by hook we don't run initialization
			# but need to reinit the hook Ref to false
			$hooked[] = false
		end

		# check for errors by errormonitor before starting new Task but after re-initialization
		isassigned($update) && isa($update[], $ExceptionFromTask) && throw($update[])

		$task[] = Task() do
			$set_update($repeatme)
		end

		$errormonitor_pluto($set_update, $task[])
		schedule($task[])
		$update[]
	end)
end


const pluto_cell_cache = Dict{UUID, Function}()
"""
	repeat_run(function_used_for_init_and_repeated_execution)
	repeat_run(function_for_init, function_for_repetition)

Repeat some long expression. It will run offline in a separate Task so that
interactivity is preserved.

Optionally, specify another expression for initialization. Initialization will
also be triggered if the cell is re-evaluated because some dependent cell or bond
changed.
"""
function repeat_run(init, repeatme=init)
	is_running_in_jolinpluto_process() || return init()
	firsttime = Main.PlutoRunner.currently_running_user_requested_run[]
	cell_id = Main.PlutoRunner.currently_running_cell_id[]

	if firsttime
		hooked = Ref(false)
		update = Ref{Any}()
		task = Ref{Task}()

		Main.PlutoRunner.UseEffectCleanups.register_cleanup(create_taskref_cleanup(task), cell_id)
		Main.PlutoRunner.UseEffectCleanups.register_cleanup(cell_id) do
			haskey(pluto_cell_cache, cell_id) && delete!(pluto_cell_cache, cell_id)
		end

		function set_update(value)
			hooked[] = true
			update[] = value
			Main.PlutoRunner.rerun_cell_from_notebook(cell_id)
			value
		end

		function _repeat_run(init, repeatme)
			if !hooked[]
				# cancel the current task when rerun. We always start a new task to work smoothely with cell disabling
				create_taskref_cleanup(task)()
				isassigned(task) && Base._wait(task[])  # Base._wait does not throw an exception
				update[] = init()
			else
				# if triggered by hook we don't run initialization
				# but need to reinit the hook Ref to false
				hooked[] = false
			end

			# check for errors by errormonitor before starting new Task but after re-initialization
			isassigned(update) && isa(update[], ExceptionFromTask) && throw(update[])

			task[] = Task() do
				sleep(0.0)
				set_update(repeatme())
			end

			errormonitor_pluto(set_update, task[])
			schedule(task[])
			update[]
		end
		pluto_cell_cache[cell_id] = _repeat_run
		_repeat_run(init, repeatme)
	else
		pluto_cell_cache[cell_id](init, repeatme)
	end
end

"""
separates args and kwargs (kwargs are returned as Dict)
"""
function _split_macro_args(args)
	_kwargs = []
	if Meta.isexpr(args[1], :parameters)
		append!(_kwargs, args[1].args)
		args = args[2:end]
	end
	i_kwargs = findfirst(x -> Meta.isexpr(x, :(=)) || Meta.isexpr(x, :kw), args)
	if i_kwargs !== nothing
		append!(_kwargs, args[i_kwargs:end])
		args = args[begin:i_kwargs-1]
	end
	@assert all(_kwargs) do kw
		Meta.isexpr(kw, :(=)) || Meta.isexpr(kw, :kw)
	end
	kwargs = Dict(
		expr.args[1] => expr.args[2]
		for expr in _kwargs
	)
	return args, kwargs
end



# this does not use an infinite process, but will spawn a new task every time
"""
	@repeat_at(ceil(now(), Second(10)), init=:wait) do t
		# code to be returned repeatedly
		rand(), t
	end

	@repeat_at(ceil(now(), Second(10)), init=:wait)

When run inside Pluto it will rerun the function on the next specified time, again
and again.

Keyword Arguments
-----------------
- `init` specifies what to do at first run or re-evaluation caused by standard
  reactivity. You can specify any code or function call (e.g. `init=nothing`, or
  `init=myinit()`). In addition there are two special values `:wait` und `:run`.
  `:wait` (default) will wait for the next time and then run the code. `:run` will
  run the code immediately without waiting.
"""
macro repeat_at(
	args...
)
	args, kwargs = _split_macro_args(args)
	if length(args) == 2
		fun = args[1]
		nexttime_from_now = args[2]
	elseif length(args) == 1
		# if only one positional arg is given, this is the time
		fun = nothing
		nexttime_from_now = args[1]
	else
		error("Possible signatures are `repeat_at(func, nexttime, init=:wait)`, `repeat_at(nexttime, init=:wait)`, ...")
	end

	# parse input expressions
	# -----------------------
	nexttime = esc(nexttime_from_now)

	if Meta.isexpr(fun, (:->, :function))
		nargs = if isa(fun.args[1], Symbol)
			1
		elseif Meta.isexpr(fun.args[1], :tuple)
			length(fun.args[1].args)
		end
		@assert nargs <= 1 "Make sure that your repeated function has maximally 1 argument."
		if nargs == 0
			fun.args[1] = Expr(:tuple, gensym(:t))
		end
		runme = esc(fun)
	else
		runme = esc(Expr(:->, gensym("t"), fun))
	end

	sleeptime_from_diff = get(kwargs, :sleeptime_from_diff, diff -> max(div(diff,2), Dates.Millisecond(5)))
	sleeptime_from_diff = esc(sleeptime_from_diff)

	# wrap runme in wait
	wait_and_runme = :(let
		nexttime = $nexttime
		diff = nexttime - $Dates.now()
		while diff > $Dates.Millisecond(0)
			sleep($sleeptime_from_diff(diff))
			diff = nexttime - $Dates.now()
		end
		$runme(nexttime)
	end)

	init = get(kwargs, :init, QuoteNode(:wait))
	# by default wait for the first time
	if init == QuoteNode(:wait)
		# for some reasons we need a let here to not interfere with other code
		init = wait_and_runme
	elseif init == QuoteNode(:run)
		init = :($runme($Dates.now()))
	else
		init = esc(init)
	end

	# return
	# ------

	:($JolinPluto.@repeat_run $init $wait_and_runme)
end



"""
	repeat_at(t -> (rand(), t), ceil(now(), Second(10)), init=:wait)

	repeat_at(ceil(now(), Second(10)), init=:wait) do t
		# code to be returned repeatedly
		rand(), t
	end

When run inside Pluto it will rerun the function on the next specified time, again
and again.

Keyword Arguments
-----------------
- `init` specifies what to do at first run or re-evaluation caused by standard
  reactivity. You can specify any function (e.g. `init=myinit_func`)or one of the two special values `:wait` und `:run`.
  `:wait` (default) will wait for the next time and then run the code. `:run` will
  run the code immediately without waiting.
"""
function repeat_at(
	repeatme,
	nexttime_from_now;
	init=:wait, # alternatives: `:run` or another function
	sleeptime_from_diff=diff -> max(div(diff,2), Dates.Millisecond(5)),
)

	# wrap runme in wait
	function wait_and_repeatme()
		nexttime = nexttime_from_now
		diff = nexttime - Dates.now()
		while diff > Dates.Millisecond(0)
			sleep(sleeptime_from_diff(diff))
			diff = nexttime - Dates.now()
		end
		repeatme(nexttime)
	end

	# by default wait for the first time
	if init == :wait
		# for some reasons we need a let here to not interfere with other code
		init = wait_and_repeatme
	elseif init == :run
		init = () -> repeatme(Dates.now())
	end

	# return
	# ------

	repeat_run(init, wait_and_repeatme)
end

repeat_at(nexttime; kwargs...) = repeat_at((time) -> nothing, nexttime; kwargs...)


"""
	nextvalue = @repeat_take! channel

This will repeatedly fetch for the next element from the given channel, re-evaluating
the cell each time a new value arrives.
"""
macro repeat_take!(channel)
	channel = esc(channel)
	:($JolinPluto.@repeat_run take!($channel))
end


"""
	nextvalue = repeat_take!(channel)

This will repeatedly fetch for the next element from the given channel, re-evaluating
the cell each time a new value arrives.
"""
function repeat_take!(channel)
	repeat_run(() -> take!(channel))
end

const repeat_take = repeat_take!

"""
    channel = @Channel(10) do ch
        for i in 1:10
            put!(ch, i)
            sleep(1)
        end
    end

Like normal `Channel`, with the underlying task being interrupted
as soon as the Pluto cell is deleted.
"""
macro Channel(args...)
    is_running_in_pluto_process() || return quote
		# just create a plain channel without cleanup
		Channel($(map(esc, args)...))
	end

	# NOTE: no need to do exception handling as channel exceptions are thrown on take!
	task = Ref{Task}()
	firsttime = Ref(true)
	:(let
		# if cell is reloaded we stop the underlying process so that the previous Channel
		# can be garbage collected
		$(create_taskref_cleanup(task))()
		chnl = Channel($(map(esc, args)...); taskref=$task)

		if $firsttime[]
			register_cleanup_fn = $(Main.PlutoRunner.GiveMeRegisterCleanupFunction)
			register_cleanup_fn($(create_taskref_cleanup(task)))
			$firsttime[] = false
		end
		chnl
	end)
end


"""
    channel = ChannelPluto(10) do ch
        for i in 1:10
            put!(ch, i)
            sleep(1)
        end
    end

Like normal `Channel`, with the underlying task being interrupted
as soon as the Pluto cell is deleted.
"""
function ChannelPluto(args...; kwargs...)
    is_running_in_jolinpluto_process() || return Channel(args...; kwargs...) # just create a plain channel without cleanup
	firsttime = Main.PlutoRunner.currently_running_user_requested_run[]
	cell_id = Main.PlutoRunner.currently_running_cell_id[]

	if firsttime
		task = Ref{Task}()
		Main.PlutoRunner.UseEffectCleanups.register_cleanup(create_taskref_cleanup(task), cell_id)
		Main.PlutoRunner.UseEffectCleanups.register_cleanup(cell_id) do
			haskey(pluto_cell_cache, cell_id) && delete!(pluto_cell_cache, cell_id)
		end
		function _ChannelPluto(args...; kwargs...)
			# NOTE: no need to do exception handling as channel exceptions are thrown on take!
			# if cell is reloaded we stop the underlying process so that the previous Channel
			# can be garbage collected
			create_taskref_cleanup(task)()
			isassigned(task) && Base._wait(task[])  # Base._wait does not throw an exception

			Channel(args...; kwargs..., taskref=task)
		end
		pluto_cell_cache[cell_id] = _ChannelPluto
		_ChannelPluto(args...; kwargs...)
	else
		pluto_cell_cache[cell_id](args...; kwargs...)
	end
end


struct NoPutType end
const NoPut = NoPutType()

"""
	ChannelWithRepeatedFill(get_next_value, 2; sleep_seconds=1.0)

Creates a ChannelPluto which calls `get_next_value` repeatedly, interleaved by calls to
sleep of the given time (defaults to 0 seconds sleep).
"""
function ChannelWithRepeatedFill(get_next_value, args...; sleep_seconds=0.0, skip_value=NoPut, kwargs...)
	ChannelPluto(args...; kwargs...) do ch
		while true
			value = get_next_value()
			value != skip_value && put!(ch, value)
			sleep(sleep_seconds)
		end
	end
end


# TODO create Pluto queue analog for Python which automatically kills the previous thread if one was started



"""
	repeat_queueget(python_queue_threaded)

Will repeatedly get elements from the queue and trigger a rerun of the current cell.
Outside pluto it will just wait for the first element to arrive and return that.

IMPORTANT: This function is only available if `import PythonCall` was executed before `import JolinPluto`.
"""
function repeat_queueget end


"""
    start_python_thread(func)  # `func` gets stop_event as the only argument

Like `threading.Thread(target=func, args=(threading.Event(),)).start()`, but such that the Event
is integrated into Pluto and will be automatically set if the thread should stop itself.

IMPORTANT: This function is only available if `import PythonCall` was executed before `import JolinPluto`.
"""
function start_python_thread end