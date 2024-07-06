# common things for both R and Python

# it turns out using a function variant of `bind` does not work well with using Pluto as a plain Julia file.
# because it might be in a nested module somewhere... and julia functions do not have access to its calling module because of possible inlining
# hence we need at least one macro call to get the module information
const _julia_module_where_plutoscript_is_included = Ref{Module}(Main)
macro init_jolin()
    _julia_module_where_plutoscript_is_included[] = __module__
    nothing
end

function init_jolin end


const _lang_bind_copy_functions = Function[]
lang_enabled(lang) = false
function lang_copy_bind end

function copy_bind_to_registered_languages(def::Symbol, value)
    lang_enabled(Val{:py}()) && lang_copy_bind(Val{:py}, def, value)
    lang_enabled(Val{:r}()) && lang_copy_bind(Val{:r}, def, value) 
end

"""
```julia
bind(symbol, element)
bind("symbol", element)
```

Return the HTML `element`, and use its latest JavaScript value as the definition of `symbol`.

# Example

```julia
bind(:x, html"<input type=range>")
```
and in another cell:
```julia
x^2
```

The first cell will show a slider as the cell's output, ranging from 0 until 100.
The second cell will show the square of `x`, and is updated in real-time as the slider is moved.
"""
function bind(def, ui)
    if !isa(def, Symbol) 
        throw(ArgumentError("""\nMacro example usage: \n\n\t@bind my_number html"<input type='range'>"\n\n"""))
    elseif !isdefined(Main, :PlutoRunner)
        initial_value_getter = try
            Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value
        catch
            b -> missing
        end
        initial_value = Core.applicable(Base.get, ui) ? Base.get(ui) : initial_value_getter(ui)
        setproperty(_module_where_plutoscript_is_included[], def, initial_value)
        copy_bind_to_registered_languages(def, initial_value)
        # It seems we need to hardcode the support in here
        return ui
    else
        Main.PlutoRunner.load_integrations_if_needed()
		initial_value_getter = Main.PlutoRunner.initial_value_getter_ref[](ui)
        initial_value = Core.applicable(Base.get, ui) ? Base.get(ui) : initial_value_getter(ui)
        setproperty!(Main.PlutoRunner.currently_running_module[], def, initial_value)
        copy_bind_to_registered_languages(def, initial_value)
        return Main.PlutoRunner.create_bond(ui, def, Main.PlutoRunner.currently_running_cell_id[])
    end
end

# for python and R especially 
# (python strings are automatically transformed to Julia strings in JuliaCall when calling julia functions from python)
# (same for R strings)
function bind(def::AbstractString, ui)
    bind(Symbol(def), ui)
end


# # TODO it looks difficult to relyably find out which language is currently used.
# # safest is probably a simple environment variable (while "_" looks kind of okay, it probably won't work everywhere) 
# # TODO also pick the documentation dynamically?
# function bind(args...; kwargs...)
#     fallback = :py  # we fallback to python for now, as julia uses the macro definition
#     lang = if isdefined(Main, :PlutoRunner)
#         if isdefined(Main.PlutoRunner, :notebook_lang)
#             Main.PlutoRunner.notebook_lang[]
#         else
#             fallback
#         end
#     elseif haskey(ENV, "_")
#         # TODO I guess this does not work on windows
#         original_executable = lowercase(basename(ENV["_"]))
#         if contains(original_executable, "python")
#             :py
#         elseif contains(original_executable, "julia")
#             :jl
#         elseif original_executable == "r"
#             :R
#         else
#             fallback
#         end
#     else
#         error("Could not identify which language is currently used.")
#     end
#     # using PPID seems not work for PythonCall - the PPID from julia and python is the same, both referring to the shell

#     if lang == :jl
#         return bindjl(args...; kwargs...)
#     elseif lang == :py
#         return bindpy(args...; kwargs...)
#     elseif lang == :R
#         return bindr(args...; kwargs...)
#     end
# end