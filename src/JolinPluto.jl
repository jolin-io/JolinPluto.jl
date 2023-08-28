module JolinPluto

# we use macros for everything, releasing mental load
export @get_jwt, @authorize_aws
export @repeat_take!, @repeat_at, @repeat_run, @Channel
export @output_below, @clipboard_image_to_clipboard_html
export Setter, @get, @cell_ids_create_wrapper, @cell_ids_push!

using Dates
using HTTP, JSON3, Git, JWTs, Base64
# TODO conditional dependency?
using AWS
using HypertextLiteral
using Continuables

include("plutohooks_basics.jl")
include("authorize.jl")
include("tasks.jl")
include("frontend.jl")
include("setter.jl")

end  # module
