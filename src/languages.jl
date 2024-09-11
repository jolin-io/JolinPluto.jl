# common things for both R and Python

"""
    lang_enabled(Val(:py))

Checks whether the language support is activated.
"""
lang_enabled(lang) = false

"""
    lang_set_global(Val(:py), symbol, value)

Sets the given variable on the respective language side.
"""
function lang_set_global end

"""
    lang_get_global(Val(:py), symbol)

Gets the given variable from the respective language side.
"""
function lang_get_global end



# Python specific stuff


# this is defined here so that it can also be used in standard Pluto and Julia notebooks which may use ipywidgets
""" 
    IPyWidget(ipywidget)

Wrap an ipywidget to be used inside Pluto
"""
struct IPyWidget
    widget
end