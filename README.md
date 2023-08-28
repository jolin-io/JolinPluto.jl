# JolinPluto

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jolin-io.github.io/JolinPluto.jl/dev/)
[![Build Status](https://github.com/jolin-io/JolinPluto.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jolin-io/JolinPluto.jl/actions/workflows/CI.yml?query=branch%3Amain)
<!-- [![Coverage](https://codecov.io/gh/jolin-io/JolinPluto.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jolin-io/JolinPluto.jl) -->

Welcome to our small collection of utility functions for [Pluto.jl](https://github.com/fonsp/Pluto.jl) running on [cloud.jolin.io](https://cloud.jolin.io).

Here a few highlights

| utility | description |
| ------- |:----------- |
| `@output_below` | makes the output follow below the input |
| `@repeat_run` | runs an expr again and again and again |
| `@repeat_take!` | takes the next element from a channel, again and again and again |
| `@repeat_at` | runs an expr at a specified next time, again and again and again |
| `@Channel` | Pluto-friendly wrapper around standard Base.Channel |
| `Setter`, `@get` | easy interface to create custom reactivity |

For more details see the [documentation](https://jolin-io.github.io/JolinPluto.jl/dev/).

## Other common Pluto helpers

Increase the width of the Pluto Notebook
```julia
html"""<style> main { max-width: 1400px; } </style>"""
```