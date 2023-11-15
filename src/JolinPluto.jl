module JolinPluto

# we use macros for everything, releasing mental load
export @get_jwt, @authorize_aws
export get_jwt, authorize_aws
export @repeat_take!, @repeat_at, @repeat_run, @Channel
export repeat_take!, repeat_take, repeat_at, repeat_run, ChannelPluto, repeat_queueget, repeat_put_at, NoPut
export @output_below, @clipboard_image_to_clipboard_html
export output_below, clipboard_image_to_clipboard_html, embedLargeHTML
export Setter, @get, @cell_ids_create_wrapper, @cell_ids_push!
export cell_ids_create_wrapper, cell_ids_push!, cell_ids_push

using Dates
using HTTP, JSON3, Git, JWTs, UUIDs, Base64
# TODO conditional dependency?
using AWS
using HypertextLiteral
using Continuables
import AbstractPlutoDingetjes

include("plutohooks_basics.jl")
include("authorize.jl")
include("tasks.jl")
include("frontend.jl")
include("setter.jl")

end  # module
