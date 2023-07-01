"""
    @output_below

Reverse input output, first input then output. When removing the cell with
`@output_below`, the order is reversed again.
"""
macro output_below()
    result = @htl """
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
    QuoteNode(result)
end

"""
   @clipboard_image_to_clipboard_html

Creates a little textfield where you can paste images. These images are then transformed
to self-containing html img tags and copied back to the clipboard to be entered
somewhere in Pluto.
"""
macro clipboard_image_to_clipboard_html()
	QuoteNode(HTML(raw"""
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
"""))
end

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
    if PlutoHooks.is_running_in_pluto_process()
        @htl """
        <iframe src="about:blank" $(kwargs)></iframe>
        <script>
            const embeddedFrame = currentScript.previousElementSibling;
            const pagedata = $(Main.PlutoRunner.publish_to_js(rawpagedata));
            embeddedFrame.contentWindow.document.open();
            embeddedFrame.contentWindow.document.write(pagedata);
            embeddedFrame.contentWindow.document.close();
        </script>
        """
    else
        @htl """
        <iframe src="about:blank" $(kwargs)></iframe>
        <script>
            const embeddedFrame = currentScript.previousElementSibling;
            const pagedata = $rawpagedata;
            embeddedFrame.contentWindow.document.open();
            embeddedFrame.contentWindow.document.write(pagedata);
            embeddedFrame.contentWindow.document.close();
        </script>
        """
    end
end