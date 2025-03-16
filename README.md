# JolinPluto

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jolin-io.github.io/JolinPluto.jl/dev/)
[![Build Status](https://github.com/jolin-io/JolinPluto.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jolin-io/JolinPluto.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jolin-io/JolinPluto.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jolin-io/JolinPluto.jl)

Welcome to our small collection of utility functions for [Pluto.jl](https://github.com/fonsp/Pluto.jl) running on [jolin.io](https://jolin.io).

## General Helpers

| utility | description |
| ------- |:----------- |
| `output_below` | Makes the output follow below the input. |
| `MD` | Markdown creator with special inline html support, indicated by fragments `<> ... </>`. Useful for creating complex Markdown with standard string interpolation. |
| `format_html` | Creates a single line html string, useful for string interpolation into markdown from Python and R. |
| `PlutoHTML` | Experimental. Transforms given html to use Pluto Div to split html parts for reactivity within one and the same output. |
| `clipboard_image_to_clipboard_html` | Experimental. Creates a little converter to paste images and get a Pluto html image string back which self-includes the data. Ready to be passed into another Pluto cell. |


## Macro style helpers for reactivity in Julia, compatible with Pluto.jl

| utility | description |
| ------- |:----------- |
| `@repeat_take!` | Takes the next element from a channel, again and again and again. |
| `@repeat_at` | Runs an expr at a specified next time, again and again and again. |
| `@Channel` | Pluto-friendly wrapper around standard `Base.Channel`. |
| `Setter`, `@get` | Easy interface to create custom reactivity. |


## Function style helpers for reactivity in Python and R on Jolin Cloud

| utility | description |
| ------- |:----------- |
| `viewof` | Function version of `@bind`, works only inside jolin.io for now. |
| `IPyWidget` | Wrapper to make ipywidgets bindable in Pluto. This is already automatically applied inside Python on Jolin Cloud, but in case you want to combine ipywidgets in a Julia Pluto notebook, this wrapper can be used directly. | 
| `repeat_take` | Takes the next element from a channel, again and again and again. |
| `repeat_queueget` | Takes the next element from a python queue, again and again and again. |
| `repeat_at` | Runs an expr at a specified next time, again and again and again. |
| `start_python_thread` | Pluto friendly way of starting a python thread. |
| `ChannelPluto` | Pluto-friendly wrapper around standard `Base.Channel`. |
| `ChannelWithRepeatedFill` | R-friendly helper to asnycronously use R code to fill a `Channel`. With this, ansyncronicity stays on julia side. |
| `NoPut` | Speciel default value for `ChannelWithRepeatedFill`, indicating if nothing should be put into the channel. | 
| `Setter`, `get` | Easy interface to create custom reactivity. |


## Jolin Cloud helpers

| utility | description |
| ------- |:----------- |
| `authenticate_token` | Generate a json web token from the current environment. In Jolin Cloud this uses Jolin Cloud JWT, in Github Actions this uses Github's JWT. |
| `authenticate_aws` | Authenticate against AWS given the Jolin Cloud token. You need to import `AWS.jl` for this to be available. |


## Further common Pluto snippets

increase the width of the Pluto Notebook
```julia
html"""<style> main { max-width: 1400px; } </style>"""
```
