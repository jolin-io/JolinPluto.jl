var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = JolinPluto","category":"page"},{"location":"#JolinPluto","page":"Home","title":"JolinPluto","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for JolinPluto.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [JolinPluto]","category":"page"},{"location":"#JolinPluto.Setter","page":"Home","title":"JolinPluto.Setter","text":"Setter()\nSetter(\"initial_value\")\n\nCreates a pluto interactivity which separates the setter cell from the state cell.\n\nUsage\n\nset_a = Setter(\"initial_value\")\n\n# in another cell, extract the inner state from the setter\n# such that updates will rerun this cell\na = @get set_a\n\n# in yet another cell use `set_a`\nset_a(\"new_value\")\n\n# or use a function syntax to easily access the previous value\nset_a() do prev_a\n    \"$prev_a!!\"\nend\n\n\n\n\n\n","category":"type"},{"location":"#JolinPluto.ChannelPluto-Tuple","page":"Home","title":"JolinPluto.ChannelPluto","text":"channel = ChannelPluto(10) do ch\n    for i in 1:10\n        put!(ch, i)\n        sleep(1)\n    end\nend\n\nLike normal Channel, with the underlying task being interrupted as soon as the Pluto cell is deleted.\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto.ChannelWithRepeatedFill-Tuple{Any, Vararg{Any}}","page":"Home","title":"JolinPluto.ChannelWithRepeatedFill","text":"ChannelWithRepeatedFill(get_next_value, 2; sleep_seconds=1.0)\n\nCreates a ChannelPluto which calls get_next_value repeatedly, interleaved by calls to sleep of the given time (defaults to 0 seconds sleep).\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto.MD-Tuple","page":"Home","title":"JolinPluto.MD","text":"MD(\"# Markdown String\")\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto._split_macro_args-Tuple{Any}","page":"Home","title":"JolinPluto._split_macro_args","text":"separates args and kwargs (kwargs are returned as Dict)\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto.authorize_aws","page":"Home","title":"JolinPluto.authorize_aws","text":"authorize_aws(role_arn; audience=\"\")\n\nAssume role via web identity. How to define such a role can be found here https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html#cli-configure-role-oidc\n\nCAUTION: Please note that the semicolon is really important! @authorize_aws(role_arn, audience=\"myaudience\") won't work as of now.\n\n\n\n\n\n","category":"function"},{"location":"#JolinPluto.bond-Tuple{Any, Any}","page":"Home","title":"JolinPluto.bond","text":"bond(symbol, element)\nbond(\"symbol\", element)\n\nReturn the HTML element, and use its latest JavaScript value as the definition of symbol.\n\nExample\n\nbond(:x, html\"<input type=range>\")\n\nand in another cell:\n\nx^2\n\nThe first cell will show a slider as the cell's output, ranging from 0 until 100. The second cell will show the square of x, and is updated in real-time as the slider is moved.\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto.cell_ids_create_wrapper-Tuple{}","page":"Home","title":"JolinPluto.cell_ids_create_wrapper","text":"cell_ids_wrapper = cell_ids_create_wrapper()\n\nCreates a wrapper around a Set of cell_ids so that they can be added (and removed) seamlessly and automatically from other cells.\n\nUsage\n\ncell_ids_wrapper = cell_ids_create_wrapper()\n\n# in another cell access the cellids and e.g. print the url suffix\ncell_ids = get(cell_ids_wrapper)\nprint(join(\"&isolated_cell_id=$id\" for id in cell_ids))\n\n# in yet another cell add its cell_id\ncell_ids_push!(cell_ids_wrapper)\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto.cell_ids_push!-Tuple{Setter}","page":"Home","title":"JolinPluto.cell_ids_push!","text":"cell_ids_push!(cell_ids_wrapper)\n\nAdds the cell's cell-id to the given cellidswrapper. This automatically handles retriggering of cells as needed.\n\nAlso cleanup is handled, i.e. that the cell-id is removed again if this cell is deleted.\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto.embedLargeHTML-Tuple{Any}","page":"Home","title":"JolinPluto.embedLargeHTML","text":"embedLargeHTML(html_string; width, height)\n\nFor large HTML code a simple iframe is not enough. This function will help.\n\nExample\n\nJolinPluto.embedLargeHTML(read(\"figure.html\", String); width=\"100%\", height=400)\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto.format_html-Tuple{Any}","page":"Home","title":"JolinPluto.format_html","text":"format_html(anything)\n\nTransform an object to raw html respresentation.\n\nNote, this is a single line representation so that it can also be used inside Markdown Tables.\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto.get_jwt","page":"Home","title":"JolinPluto.get_jwt","text":"get_jwt()\nget_jwt(\"exampleaudience\")\n\nCreates a JSON Web Token which can be used for authentication at common cloud providers.\n\nOn cloud.jolin.io the token will be issued and signed by cloud.jolin.io, on Github Actions (used for automated tests), a respective github token is returned.\n\n\n\n\n\n","category":"function"},{"location":"#JolinPluto.is_running_in_pluto_process-Tuple{}","page":"Home","title":"JolinPluto.is_running_in_pluto_process","text":"is_running_in_pluto_process()\n\nThis doesn't mean we're in a Pluto cell, e.g. can use @bind and hooks goodies. It only means PlutoRunner is available (and at a version that technically supports hooks)\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto.output_below-Tuple{}","page":"Home","title":"JolinPluto.output_below","text":"output_below()\n\nReverse input output, first input then output. When removing the cell with @output_below, the order is reversed again.\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto.plotly_responsive","page":"Home","title":"JolinPluto.plotly_responsive","text":"plotly_responsive()\nplotly_responsive(plot_object)\n\nIMPORTANT: Works only if plotly() backend is activated\n\nMakes the plotly plot responsive and returns the new plot.\n\n\n\n\n\n","category":"function"},{"location":"#JolinPluto.repeat_at-Tuple{Any, Any}","page":"Home","title":"JolinPluto.repeat_at","text":"repeat_at(t -> (rand(), t), ceil(now(), Second(10)), init=:wait)\n\nrepeat_at(ceil(now(), Second(10)), init=:wait) do t\n\t# code to be returned repeatedly\n\trand(), t\nend\n\nWhen run inside Pluto it will rerun the function on the next specified time, again and again.\n\nKeyword Arguments\n\ninit specifies what to do at first run or re-evaluation caused by standard reactivity. You can specify any function (e.g. init=myinit_func)or one of the two special values :wait und :run. :wait (default) will wait for the next time and then run the code. :run will run the code immediately without waiting.\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto.repeat_queueget","page":"Home","title":"JolinPluto.repeat_queueget","text":"repeat_queueget(python_queue_threaded)\n\nWill repeatedly get elements from the queue and trigger a rerun of the current cell. Outside pluto it will just wait for the first element to arrive and return that.\n\nIMPORTANT: This function is only available if import PythonCall was executed before import JolinPluto.\n\n\n\n\n\n","category":"function"},{"location":"#JolinPluto.repeat_run","page":"Home","title":"JolinPluto.repeat_run","text":"repeat_run(function_used_for_init_and_repeated_execution)\nrepeat_run(function_for_init, function_for_repetition)\n\nRepeat some long expression. It will run offline in a separate Task so that interactivity is preserved.\n\nOptionally, specify another expression for initialization. Initialization will also be triggered if the cell is re-evaluated because some dependent cell or bond changed.\n\n\n\n\n\n","category":"function"},{"location":"#JolinPluto.repeat_take!-Tuple{Any}","page":"Home","title":"JolinPluto.repeat_take!","text":"nextvalue = repeat_take!(channel)\n\nThis will repeatedly fetch for the next element from the given channel, re-evaluating the cell each time a new value arrives.\n\n\n\n\n\n","category":"method"},{"location":"#JolinPluto.start_python_thread","page":"Home","title":"JolinPluto.start_python_thread","text":"start_python_thread(func)  # `func` gets stop_event as the only argument\n\nLike threading.Thread(target=func, args=(threading.Event(),)).start(), but such that the Event is integrated into Pluto and will be automatically set if the thread should stop itself.\n\nIMPORTANT: This function is only available if import PythonCall was executed before import JolinPluto.\n\n\n\n\n\n","category":"function"},{"location":"#JolinPluto.@Channel-Tuple","page":"Home","title":"JolinPluto.@Channel","text":"channel = @Channel(10) do ch\n    for i in 1:10\n        put!(ch, i)\n        sleep(1)\n    end\nend\n\nLike normal Channel, with the underlying task being interrupted as soon as the Pluto cell is deleted.\n\n\n\n\n\n","category":"macro"},{"location":"#JolinPluto.@authorize_aws","page":"Home","title":"JolinPluto.@authorize_aws","text":"@authorize_aws(role_arn; audience=\"\")\n\nAssume role via web identity. How to define such a role can be found here https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html#cli-configure-role-oidc\n\nCAUTION: Please note that the semicolon is really important! @authorize_aws(role_arn, audience=\"myaudience\") won't work as of now.\n\n\n\n\n\n","category":"macro"},{"location":"#JolinPluto.@cell_ids_create_wrapper-Tuple{}","page":"Home","title":"JolinPluto.@cell_ids_create_wrapper","text":"cell_ids_wrapper = @cell_ids_create_wrapper()\n\nCreates a wrapper around a Set of cell_ids so that they can be added (and removed) seamlessly and automatically from other cells.\n\nUsage\n\ncell_ids_wrapper = @cell_ids_create_wrapper()\n\n# in another cell access the cellids and e.g. print the url suffix\ncell_ids = @get cell_ids_wrapper\nprint(join(\"&isolated_cell_id=$id\" for id in cell_ids))\n\n# in yet another cell add its cell_id\n@cell_ids_push! cell_ids_wrapper\n\n\n\n\n\n","category":"macro"},{"location":"#JolinPluto.@cell_ids_push!-Tuple{Any}","page":"Home","title":"JolinPluto.@cell_ids_push!","text":"@cell_ids_push! cell_ids_wrapper\n\nAdds the cell's cell-id to the given cellidswrapper. This automatically handles retriggering of cells as needed.\n\nAlso cleanup is handled, i.e. that the cell-id is removed again if this cell is deleted.\n\n\n\n\n\n","category":"macro"},{"location":"#JolinPluto.@clipboard_image_to_clipboard_html-Tuple{}","page":"Home","title":"JolinPluto.@clipboard_image_to_clipboard_html","text":"@clipboardimagetoclipboardhtml\n\nCreates a little textfield where you can paste images. These images are then transformed to self-containing html img tags and copied back to the clipboard to be entered somewhere in Pluto.\n\n\n\n\n\n","category":"macro"},{"location":"#JolinPluto.@get_jwt","page":"Home","title":"JolinPluto.@get_jwt","text":"@get_jwt\n@get_jwt \"exampleaudience\"\n\nCreates a JSON Web Token which can be used for authentication at common cloud providers.\n\nOn cloud.jolin.io the token will be issued and signed by cloud.jolin.io, on Github Actions (used for automated tests), a respective github token is returned.\n\n\n\n\n\n","category":"macro"},{"location":"#JolinPluto.@give_me_register_cleanup_function-Tuple{}","page":"Home","title":"JolinPluto.@give_me_register_cleanup_function","text":"@give_me_register_cleanup_function()\n\n⚠️ Don't use this directly!! if you think you need it, you need @use_effect.\n\nUsed inside a Pluto cell this will resolve to a function that call be called with yet another function, and then will call that function when the cell gets explicitly re-run. (\"Explicitly re-run\" meaning all @use_refs get cleared, for example). Outside a Pluto cell it will throw an error.\n\n\n\n\n\n","category":"macro"},{"location":"#JolinPluto.@give_me_rerun_cell_function-Tuple{}","page":"Home","title":"JolinPluto.@give_me_rerun_cell_function","text":"@give_me_rerun_cell_function()\n\n⚠️ Don't use this directly!! if you think you need it, you need @use_state.\n\nUsed inside a Pluto cell this will resolve to a function that, when called, will cause the cell to be re-run (in turn re-running all dependent cells). Outside a Pluto cell it will throw an error.\n\n\n\n\n\n","category":"macro"},{"location":"#JolinPluto.@give_me_the_pluto_cell_id-Tuple{}","page":"Home","title":"JolinPluto.@give_me_the_pluto_cell_id","text":"@give_me_the_pluto_cell_id()\n\n⚠️ Don't use this directly!! if you think you need it, you might actually need @use_did_deps_change([]) but even that is unlikely.\n\nUsed inside a Pluto cell this will resolve to the current cell UUID. Outside a Pluto cell it will throw an error.\n\n\n\n\n\n","category":"macro"},{"location":"#JolinPluto.@output_below-Tuple{}","page":"Home","title":"JolinPluto.@output_below","text":"@output_below\n\nReverse input output, first input then output. When removing the cell with @output_below, the order is reversed again.\n\n\n\n\n\n","category":"macro"},{"location":"#JolinPluto.@repeat_at-Tuple","page":"Home","title":"JolinPluto.@repeat_at","text":"@repeat_at(ceil(now(), Second(10)), init=:wait) do t\n\t# code to be returned repeatedly\n\trand(), t\nend\n\n@repeat_at(ceil(now(), Second(10)), init=:wait)\n\nWhen run inside Pluto it will rerun the function on the next specified time, again and again.\n\nKeyword Arguments\n\ninit specifies what to do at first run or re-evaluation caused by standard reactivity. You can specify any code or function call (e.g. init=nothing, or init=myinit()). In addition there are two special values :wait und :run. :wait (default) will wait for the next time and then run the code. :run will run the code immediately without waiting.\n\n\n\n\n\n","category":"macro"},{"location":"#JolinPluto.@repeat_run","page":"Home","title":"JolinPluto.@repeat_run","text":"@repeat_run(expr_used_for_init_and_repeated_execution)\n@repeat_run(expr_for_init, expr_for_repetition)\n\nRepeat some long expression. It will run offline in a separate Task so that interactivity is preserved.\n\nOptionally, specify another expression for initialization. Initialization will also be triggered if the cell is re-evaluated because some dependent cell or bond changed.\n\n\n\n\n\n","category":"macro"},{"location":"#JolinPluto.@repeat_take!-Tuple{Any}","page":"Home","title":"JolinPluto.@repeat_take!","text":"nextvalue = @repeat_take! channel\n\nThis will repeatedly fetch for the next element from the given channel, re-evaluating the cell each time a new value arrives.\n\n\n\n\n\n","category":"macro"}]
}
