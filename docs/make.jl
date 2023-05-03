using JolinPluto
using Documenter

DocMeta.setdocmeta!(JolinPluto, :DocTestSetup, :(using JolinPluto); recursive=true)

makedocs(;
    modules=[JolinPluto],
    authors="Stephan Sahm <stephan.sahm@jolin.io> and contributors",
    repo="https://github.com/jolin-io/JolinPluto.jl/blob/{commit}{path}#{line}",
    sitename="JolinPluto.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://jolin-io.github.io/JolinPluto.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jolin-io/JolinPluto.jl",
    devbranch="main",
)
