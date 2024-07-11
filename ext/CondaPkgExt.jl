module CondaPkgExt
import CondaPkg
function __init__()
    # this is crucial so that the path is set correctly
    # while PythonCall does this by itself, RCall needs this manual help, 
    # which effects both plain Julia with RCall as well as PlutoR
    CondaPkg.activate!(ENV)
end
end