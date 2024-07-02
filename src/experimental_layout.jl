"""
    format_html(anything)

Transform an object to raw html respresentation.

Note, this is a single line representation so that it can also be used inside Markdown Tables.
"""
function format_html(ans)
    isdefined(Main, :PlutoRunner) || return repr("text/html", ans)

    str, mime = Main.PlutoRunner.format_output(ans; context=PlutoRunner.IOContext(
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


layout(html::HypertextLiteral.Result) = layout(format_html(html))
layout(html::AbstractString) = layout(parsehtml(html, noerror=true))
function layout(html::EzXML.Document)
    body = only(elements(root(html)))
    # make the outer level always an ExperimentalLayout (and not an @htl)
    # because of https://github.com/JuliaPluto/PlutoUI.jl/issues/284
    if countelements(body) == 1
        layout(elements(body)[1])
    elseif countelements(body) > 1
        PlutoUI.ExperimentalLayout.Div(layout.(elements(body)))
    end
end
function layout(node::EzXML.Node)
    res = if nodename(node) == "div" && countelements(node) > 1
        PlutoUI.ExperimentalLayout.Div(
            layout.(nodes(node)),
            class=getdefault(node, "class", nothing),
            style=getdefault(node, "style", ""),
        )
    elseif iselement(node) && nodename(node) == "bond"
        # special case - we do not want to recurse into pluto bind elements
        HTML(sprint(print, node))
    elseif iselement(node)
        attrs = Dict(nodename(a) => nodecontent(a) for a in eachattribute(node))
        @htl "<$(nodename(node)) $attrs>$(layout.(nodes(node))...)</$(nodename(node))>"
    elseif istext(node)
        @htl "$(nodecontent(node))"
    else 
        HTML(sprint(print, node))
    end
    return res
end