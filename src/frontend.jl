using EzXML
import AbstractPlutoDingetjes

public output_below, format_html, MD

"""
    output_below()

Reverse input output, first input then output. When removing the cell with
`@output_below`, the order is reversed again.
"""
output_below() = @htl """
    <style>
    pluto-notebook[swap_output] pluto-cell {
        display: flex;
        flex-direction: column;
    }
    pluto-notebook[swap_output] pluto-cell pluto-output {
        order: 2;
    }
    pluto-notebook[swap_output] pluto-cell pluto-runarea {
        order: 1;
        position: relative;
        margin-left: auto;
        height: 17px;
        margin-bottom: -17px;
        z-index: 20;
    }
    </style>

    <script>
    const plutoNotebook = document.querySelector("pluto-notebook")
    plutoNotebook.setAttribute('swap_output', "")
    /* invalidation is a pluto feature and will be triggered when the cell is deleted */
    invalidation.then(() => cell.removeAttribute("swap_output"))
    </script>
    """


"""
   clipboard_image_to_clipboard_html()

Creates a little textfield where you can paste images. These images are then transformed
to self-containing html img tags and copied back to the clipboard to be entered
somewhere in Pluto.
"""
clipboard_image_to_clipboard_html() = HTML(raw"""
    <div contentEditable = true>
        <script>
        const div = currentScript.parentElement
        const img = div.querySelector("img")
        const p = div.querySelector("p")

        div.onpaste = function(e) {
            var data = e.clipboardData.items[0].getAsFile();
            var fr = new FileReader;
            fr.onloadend = function() {
                // fr.result is all data
                let juliastr = `html"<img src='${fr.result}'/>"`;
                navigator.clipboard.writeText(juliastr);
            };
            fr.readAsDataURL(data);
        };
        </script>
    </div>
    """)

# adapted from https://github.com/fonsp/Pluto.jl/issues/2551#issuecomment-1536622637
# and https://github.com/fonsp/Pluto.jl/issues/2551#issuecomment-1551668938
"""
    embedLargeHTML(html_string; width, height)

For large HTML code a simple iframe is not enough. This function will help.

Example
-------
```julia
JolinPluto.embedLargeHTML(read("figure.html", String); width="100%", height=400)
```
"""
function embedLargeHTML(rawpagedata; kwargs...)
    pagedata = if is_running_in_pluto_process()
        AbstractPlutoDingetjes.Display.published_to_js(rawpagedata)
    else
        rawpagedata
    end

    return @htl """
    <iframe src="about:blank" $(kwargs)></iframe>
    <script>
        const embeddedFrame = currentScript.previousElementSibling;
        const pagedata = $pagedata;
        embeddedFrame.contentWindow.document.open();
        embeddedFrame.contentWindow.document.write(pagedata);
        embeddedFrame.contentWindow.document.close();
    </script>
    """
end


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

Markdown parser with special support for inline html fenced by `<>...</>`.
As `format_html` returns single line html, this makes it possible to interpolate arbitrary html into markdown tables.
"""
function MD(args...; kwargs...)
    _MD_parser(args...; kwargs...)
end


"""
    format_html(anything)

Transform an object to raw html respresentation.

Note, this is a single line representation so that it can also be used inside Markdown Tables.
"""
function format_html(ans)
    isdefined(Main, :PlutoRunner) || return repr("text/html", ans)

    str, mime = Main.PlutoRunner.format_output(ans; context=Main.PlutoRunner.IOContext(
        Main.PlutoRunner.default_iocontext,
        :extra_items=>Dict{Main.PlutoRunner.ObjectDimPair,Int64}(),
        :module => Main.PlutoRunner.currently_running_module[],
        :pluto_notebook_id => Main.PlutoRunner.notebook_id[],
        :pluto_cell_id => Main.PlutoRunner.currently_running_cell_id[],
    ))
    function replace_script_inner(script_str)
        # core idea to make it single_line: we eval a string
        # for this we need to escape
        # escape single strings inside and then wrap everything into one single quote string
        # escape single strings inside and then wrap everything into one single quote string
        raw"return await eval('(async function() {\n" * replace(script_str,
            r"(?<=\\)'" => raw"\\'",
            r"(?<!\\)'" => raw"\'",
            r"\\n" => raw"\\n",
            r"\n" => raw"\n",
        ) * raw"\n})()')"
    end
    str_script_singleline = replace(str, r"(?<=<script>).*(?=</script>)"s => replace_script_inner)
    str_singleline = replace(str_script_singleline, r"\s*(\n|\r\n)\s*" => " ")
    str_singleline
end


# experimental layout (HTML wrapper which uses Pluto Div to correctly separate outputs and inputs)

PlutoHTML(html::HypertextLiteral.Result) = PlutoHTML(format_html(html))
PlutoHTML(md::CommonMark.Node) = PlutoHTML(format_html(md))
PlutoHTML(html::AbstractString) = PlutoHTML(parsehtml(html, noerror=true))
function PlutoHTML(html::EzXML.Document)
    body = only(elements(root(html)))
    # make the outer level always an ExperimentalLayout (and not an @htl)
    # because of https://github.com/JuliaPluto/PlutoUI.jl/issues/284
    if countelements(body) == 1
        PlutoHTML(elements(body)[1])
    elseif countelements(body) > 1
        PlutoUI.ExperimentalLayout.Div(PlutoHTML.(elements(body)))
    end
end

function PlutoHTML(node::EzXML.Node)
    res = if nodename(node) == "div" && countelements(node) > 1
        PlutoUI.ExperimentalLayout.Div(
            PlutoHTML.(nodes(node)),
            class=getdefault(node, "class", nothing),
            style=getdefault(node, "style", ""),
        )
    elseif iselement(node) && nodename(node) == "bond"
        # special case - we do not want to recurse into pluto bind elements
        HTML(sprint(print, node))
    elseif iselement(node)
        attrs = Dict(nodename(a) => nodecontent(a) for a in eachattribute(node))
        @htl "<$(nodename(node)) $attrs>$(PlutoHTML.(nodes(node))...)</$(nodename(node))>"
    elseif istext(node)
        @htl "$(nodecontent(node))"
    else 
        HTML(sprint(print, node))
    end
    return res
end