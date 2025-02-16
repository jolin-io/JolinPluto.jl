
# doctests run here instead of inside a testitem because it fails currently wit
# ┌ Error: Failed to evaluate `CurrentModule = JolinPluto` in `@meta` block.
# │   exception =
# │    UndefVarError: `JolinPluto` not defined in `Main`
# │    Suggestion: check for spelling errors or missing imports.
# │    Hint: JolinPluto is loaded but not imported in the active module Main.
# └ @ Documenter ~/.julia/packages/Documenter/iwb7N/src/utilities/utilities.jl:44

using JolinPluto
using Documenter
DocMeta.setdocmeta!(JolinPluto, :DocTestSetup, :(using JolinPluto), recursive=true)
doctest(JolinPluto)

using TestItemRunner
@run_package_tests