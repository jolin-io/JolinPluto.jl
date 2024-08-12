"""
```julia
viewof(:symbol, element)
viewof("symbol", element)
```

Return the HTML `element`, and use its latest JavaScript value as the definition of `symbol`.

# Example

```julia
viewof(:x, html"<input type=range>")
```
and in another cell:
```julia
x^2
```

The first cell will show a slider as the cell's output, ranging from 0 until 100.
The second cell will show the square of `x`, and is updated in real-time as the slider is moved.
"""
function viewof(def, ui)
    if !isa(def, Symbol) 
        throw(ArgumentError("""\nMacro example usage: \n\n\t@bind my_number html"<input type='range'>"\n\n"""))
    elseif !isdefined(Main, :PlutoRunner)
        initial_value_getter = try
            Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value
        catch
            b -> missing
        end
        initial_value = Core.applicable(Base.get, ui) ? Base.get(ui) : initial_value_getter(ui)
        return initial_value, ui
    else
        Main.PlutoRunner.load_integrations_if_needed()
		initial_value_getter = Main.PlutoRunner.initial_value_getter_ref[](ui)
        initial_value = Core.applicable(Base.get, ui) ? Base.get(ui) : initial_value_getter(ui)
        return initial_value, Main.PlutoRunner.create_bond(ui, def, Main.PlutoRunner.currently_running_cell_id[])
    end
end

# for python and R especially 
# (python strings are automatically transformed to Julia strings in JuliaCall when calling julia functions from python)
# (same for R strings)
function viewof(def::AbstractString, ui)
    viewof(Symbol(def), ui)
end
