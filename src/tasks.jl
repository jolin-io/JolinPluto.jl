
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
    PlutoHooks.is_running_in_pluto_process() || return quote
		# just create a plain channel without cleanup
		Channel($(map(esc, args)...))
	end

	# NOTE: no need to do exception handling as channel exceptions are thrown on take!
	taskref = Ref{Task}()
	quote
		# if cell is reloaded we stop the underlying process so that the previous Channel
		# can be garbage collected
		$(create_taskref_cleanup(taskref))()
		chnl = Channel($(map(esc, args)...); taskref=$taskref)

		if PlutoHooks.@use_did_deps_change([])
			register_cleanup_fn = PlutoHooks.@give_me_register_cleanup_function
			register_cleanup_fn($(create_taskref_cleanup(taskref)))
		end
		chnl
	end
end



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


macro use_state_reinit(init)
	updated_by_hooks_ref = Ref(false)
	upgrade_set_update(set_update) = function set_update_upgraded(arg)
		updated_by_hooks_ref[] = true
		set_update(arg)
	end
	quote
		update, set_update = @use_state(nothing)
		hooked = $updated_by_hooks_ref[]
		if !hooked
			# if we are not updated by hooks, but by other triggers, we also want to reinitiate things
			# this is also for the first time, which is why we do not need the standard init value above
			update = $(esc(init))
		end
		# reset to false for a new round
		$updated_by_hooks_ref[] = false
		update, $upgrade_set_update(set_update), hooked
	end
end


create_taskref_cleanup(taskref, exception=SilentlyCancelTask) = function ()
	isassigned(taskref) || return nothing
	task = taskref[]
	task !== nothing && !istaskdone(task) || return nothing
	try
		Base.schedule(task, exception(), error=true)
	catch error
		nothing
	end
end



# this does not use an infinite process, but will spawn a new task every time
macro repeat_run(
	fun,
	nexttime_from_now,
	keywords...,
)
	# parse input expressions
	# -----------------------
	nexttime = esc(nexttime_from_now)

	if Meta.isexpr(fun, (:->, :function))
		nargs = if isa(fun.args[1], Symbol)
			1
		elseif Meta.isexpr(fun.args[1], :tuple)
			length(fun.args[1].args)
		end
		@assert nargs <= 1
		if nargs == 0
			fun.args[1] = Expr(:tuple, gensym(:t))
		end
		runme = esc(fun)
	else
		runme = esc(Expr(:->, gensym("t"), fun))
	end

	@assert all(keywords) do kw
		Meta.isexpr(kw, :(=)) || Meta.isexpr(kw, :kw)
	end
	kwargs = Dict(
		expr.args[1] => expr.args[2]
		for expr in keywords
	)
	sleeptime_from_diff = get(kwargs, :sleeptime_from_diff, diff -> max(div(diff,2), Dates.Millisecond(5)))

	init = get(kwargs, :init, QuoteNode(:wait))
	# by default wait for the first time
	if init == QuoteNode(:wait)
		init = quote
			nexttime = $nexttime
			diff = nexttime - $Dates.now()
			while diff > $Dates.Millisecond(0)
				sleep($(esc(sleeptime_from_diff))(diff))
				diff = nexttime - $Dates.now()
			end
			$runme(nexttime)
		end
	else
		init = esc(init)
	end

	# return
	# ------

	PlutoHooks.is_running_in_pluto_process() || return quote
		$(esc(init))
	end

	taskref = Ref{Task}()
	quote
		# kill a possibly running task.
		# even if this is refreshed by hook, there should not be any task running, hence
		# this is almost a no-op.
		# Note that this really needs to be run before init, as init may take! and block
		# so that a possibly still running but invalid task would interfere.
		$(create_taskref_cleanup(taskref))()

		# use_did_deps_change([]) will return true if the cell id changes
		# or the given variables. Normally the cell-id only changes when the
		# cell is rerun manually. Exactly that often we need to register the
		# cleanup function.
		if PlutoHooks.@use_did_deps_change([])
			register_cleanup_fn = PlutoHooks.@give_me_register_cleanup_function()
			register_cleanup_fn($(create_taskref_cleanup(taskref)))
		end

		update, set_update, hooked = @use_state_reinit($init)
		isa(update, ExceptionFromTask) && throw(update)

		taskref = $taskref
		taskref[] = Task() do
			nexttime = $nexttime
			diff = nexttime - $Dates.now()
			while diff > $Dates.Millisecond(0)
				sleep($(esc(sleeptime_from_diff))(diff))
				diff = nexttime - $Dates.now()
			end
			set_update($runme(nexttime))
        end
		errormonitor_pluto(set_update, taskref[])
		schedule(taskref[])
        update
    end
end


macro repeat_take!(channel)
    PlutoHooks.is_running_in_pluto_process() || return quote
		take!($(esc(channel)))
	end

	taskref = Ref{Task}()
	quote
		# kill a possibly running task.
		# even if this is refreshed by hook, there should not be any task running, hence
		# this is almost a no-op.
		# Note that this really needs to be run before init, as init may take! and block
		# so that a possibly still running but invalid task would interfere.
		$(create_taskref_cleanup(taskref))()

		# use_did_deps_change([]) will return true if the cell id changes
		# or the given variables. Normally the cell-id only changes when the
		# cell is rerun manually. Exactly that often we need to register the
		# cleanup function.
		if PlutoHooks.@use_did_deps_change([])
			register_cleanup_fn = PlutoHooks.@give_me_register_cleanup_function()
			register_cleanup_fn($(create_taskref_cleanup(taskref)))
		end

		channel = $(esc(channel))
		update, set_update, hooked = @use_state_reinit(take!(channel))
		isa(update, ExceptionFromTask) && throw(update)

		taskref = $taskref
		taskref[] = Task() do
			_channel = channel
			set_update(take!(_channel))
		end
		schedule(taskref[])
		# because every exception in the Channel is stable
		# we can do the Exception check after scheduling the task
		# this way adapting other cells can indeed auto-update this cell
		errormonitor_pluto(set_update, taskref[])
		update
	end
end