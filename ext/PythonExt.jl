module PythonExt

import JolinPluto
using PythonCall

function JolinPluto.repeat_queueget(q)
    function _repeat_queueget()
        while PythonCall.pytruth(q.empty())
            sleep(0.0)
        end
        # this is guaranteed to work as long as there is only a single repeat_queueget on a queue
        q.get_nowait()
    end
    JolinPluto.repeat_run(_repeat_queueget)
end

function JolinPluto.start_python_thread(func)
    threading = @pyconst(pyimport("threading"))

    if !JolinPluto.is_running_in_pluto_process()
        # just start a plain thread without cleanup
        stop_event = threading.Event()
        threading.Thread(target=func, args=(stop_event,)).start()
        return stop_event
    end

	firsttime = Main.PlutoRunner.currently_running_user_requested_run[]
	cell_id = Main.PlutoRunner.currently_running_cell_id[]

    if firsttime
        stop_event_ref = Ref{Any}()
        function cleanup_func()
            isassigned(stop_event_ref) && stop_event_ref[].set()
            nothing
        end
        Main.PlutoRunner.UseEffectCleanups.register_cleanup(cleanup_func, cell_id)
        Main.PlutoRunner.UseEffectCleanups.register_cleanup(cell_id) do
			haskey(JolinPluto.pluto_cell_cache, cell_id) && delete!(JolinPluto.pluto_cell_cache, cell_id)
		end

        function _start_python_thread(func)
			# NOTE: no need to do exception handling as channel exceptions are thrown on take!
			# if cell is reloaded we stop the underlying process so that the previous Channel
			# can be garbage collected
			cleanup_func()
            stop_event_ref[] = threading.Event()
			threading.Thread(target=func, args=(stop_event_ref[],)).start()
            return stop_event_ref[]
		end
        JolinPluto.pluto_cell_cache[cell_id] = _start_python_thread
        _start_python_thread(func)
    else
        JolinPluto.pluto_cell_cache[cell_id](func)
    end
end
end