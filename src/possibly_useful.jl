

_free_symbols(sym::Symbol) = @cont isdefined(Main, sym) || cont(sym)
_free_symbols(other) = @cont ()

get_where_symbol(sym::Symbol) = sym
function get_where_symbol(expr::Expr)
	if expr.head === :comparison
		expr.args[3]
	elseif expr.head in (:(<:), :(>:))
		expr.args[1]
	else
		error("should not happen")
	end
end

@cont function _free_symbols(expr::Expr)
	if expr.head ∈ (:function, :->)
		call = expr.args[1]
		body = expr.args[2]

		func_args = if isa(call, Symbol)
			(call,)
		elseif call.head === :tuple
			call.args
		elseif call.head === :call
			call.args[2:end]
		end

		foreach(_free_symbols(body)) do sym
			sym ∈ func_args || cont(sym)
		end
	elseif expr.head === :ref
		# this is indexing, where the symbols :end and :begin have special meaning
		for arg in expr.args
			foreach(_free_symbols(arg)) do sym
				sym ∈ (:begin, :end) || cont(sym)
			end
		end
	elseif expr.head === :where
		where_symbols = get_where_symbol.(expr.args[2:end])
		for arg in expr.args
			foreach(_free_symbols(arg)) do sym
				sym ∈ where_symbols || cont(sym)
			end
		end
	else
		defs = []
		for arg in expr.args
			if Meta.isexpr(arg, :(=))
				push!(defs, arg.args[1])
			end

			foreach(_free_symbols(arg)) do sym
				sym in defs || cont(sym)
			end
		end
	end
end