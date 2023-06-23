module JolinPluto

# we use macros for everything to release mental load here
export @get_jwt, @authorize_aws, @repeat_take!, @repeat_run, @output_below, @Channel, @clipboard_image_to_clipboard_html

using Dates
using HTTP, JSON3, Git, JWTs, Base64
# TODO conditional dependency?
using AWS
using HypertextLiteral
using PlutoHooks, PlutoLinks
using Continuables

include("authorize.jl")
include("tasks.jl")
include("frontend.jl")

end  # module
