# common things for both R and Python

# We build an individual CommonMark parser with a special inline `<> ... </>` component.
import CommonMark

struct HtmlFragmentInlineRule end
struct HtmlFragmentInline <: CommonMark.AbstractInline end
function parse_html_fragment(parser::CommonMark.InlineParser, block::CommonMark.Node)
    m = CommonMark.consume(parser, match(r"<>.*</>", parser))
    m === nothing && return false
    node = CommonMark.Node(HtmlFragmentInline())
    node.literal = @views m.match[begin+length("<>"):end-length("</>")]
    CommonMark.append_child(block, node)
    return true
end
CommonMark.inline_rule(::HtmlFragmentInlineRule) = CommonMark.Rule(parse_html_fragment, 1.5, "<")

function CommonMark.write_term(::HtmlFragmentInline, render, node, enter)
    # macroexpand solves this problem https://discourse.julialang.org/t/how-to-properly-import-a-macro-inside-a-begin-end-block/106037/4
    style = @macroexpand CommonMark.crayon"dark_gray"
    CommonMark.print_literal(render, style)
    CommonMark.push_inline!(render, style)
    CommonMark.print_literal(render, node.literal)
    CommonMark.pop_inline!(render)
    CommonMark.print_literal(render, inv(style))
end
CommonMark.write_html(::HtmlFragmentInline, r, n, ent) = CommonMark.literal(r, r.format.safe ? "<!-- raw HTML omitted -->" : n.literal)
CommonMark.write_latex(::HtmlFragmentInline, w, node, ent) = nothing
CommonMark.write_markdown(::HtmlFragmentInline, w, node, ent) = CommonMark.literal(w, node.literal)

const _MD_parser = CommonMark.Parser()
CommonMark.enable!(_MD_parser, CommonMark.DollarMathRule())
CommonMark.enable!(_MD_parser, CommonMark.TableRule())
CommonMark.enable!(_MD_parser, HtmlFragmentInlineRule())

"""
    MD("# Markdown String")
"""
function MD(args...; kwargs...)
    _MD_parser(args...; kwargs...)
end




# extra helpers around RCall

function bindr end

# extra helpers around Python

function bindpy end

# helper to bind with function instead of macro in julia

"""
```julia
bind(symbol, element)
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
function bindjl(def, element)
    if !isa(def, Symbol) 
        throw(ArgumentError("""\nMacro example usage: \n\n\t@bind my_number html"<input type='range'>"\n\n"""))
    elseif !isdefined(Main, :PlutoRunner)
        initial_value_getter = try
            Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value
        catch
            b -> missing
        end
        @eval global $def = Core.applicable(Base.get, $element) ? Base.get($element) : $initial_value_getter($element)
        return element
    else
        Main.PlutoRunner.load_integrations_if_needed()
		initial_value_getter = Main.PlutoRunner.initial_value_getter_ref[](ui)
        @eval global $def = Core.applicable(Base.get, $element) ? Base.get($element) : $initial_value_getter($element)
        return Main.PlutoRunner.create_bond(element, def, Main.PlutoRunner.currently_running_cell_id[])
    end
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