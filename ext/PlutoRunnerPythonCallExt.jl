module PythonExt
import PythonCall
import PlutoRunner

# ignore Python objects in the expr_hash (deserialization is introducing new objectids)
PlutoRunner.expr_hash(::PythonCall.Py) = zero(PlutoRunner.ObjectID)

end  # module