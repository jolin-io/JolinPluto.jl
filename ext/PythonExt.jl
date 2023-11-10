module PythonExt

import JolinPluto, PythonCall

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

end