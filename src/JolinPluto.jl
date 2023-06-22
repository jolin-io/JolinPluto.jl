module JolinPluto

# we use macros for everything to release mental load here
export @get_jwt, @authorize_aws, @take_repeatedly!, @repeaton, @output_below, @Channel, @clipboard_image_to_clipboard_html

using Dates
using HTTP, JSON3, Git, JWTs, Base64
# TODO conditional dependency?
using AWS
using HypertextLiteral
using PlutoHooks, PlutoLinks
using Continuables

# Taken from https://github.com/JuliaPluto/PlutoHooks.jl/blob/main/src/notebook.jl#L74-L86
"""
	is_running_in_pluto_process()
This doesn't mean we're in a Pluto cell, e.g. can use @bind and hooks goodies.
It only means PlutoRunner is available (and at a version that technically supports hooks)
"""
function is_running_in_pluto_process()
	isdefined(Main, :PlutoRunner) &&
	# Also making sure my favorite goodies are present
	isdefined(Main.PlutoRunner, :GiveMeCellID) &&
	isdefined(Main.PlutoRunner, :GiveMeRerunCellFunction) &&
	isdefined(Main.PlutoRunner, :GiveMeRegisterCleanupFunction) &&
    isdefined(Main.PlutoRunner, :publish_to_js)
end


macro get_jwt(audience="")
    # Jolin Cloud
    if parse(Bool, get(ENV, "JOLIN_CLOUD", "false"))
        serviceaccount_token = readchomp("/var/run/secrets/kubernetes.io/serviceaccount/token")
        path = split(String(__source__.file),"#==#")[1]
        project_dir = readchomp(`$(git()) -C $(dirname(path)) rev-parse --show-toplevel`)
        @assert startswith(path, project_dir) "invalid workflow location"
        workflowpath = path[length(project_dir)+2:end]
        quote
            response = $HTTP.get("http://jolin-workspace-server-jwts.jolin-workspace-server/request_jwt",
                query=["serviceaccount_token" => $serviceaccount_token,
                        "workflowpath" => $workflowpath,
                        "audience" => $(esc(audience))])
            $JSON3.read(response.body).token
        end
    # Github Actions
    elseif (parse(Bool, get(ENV, "CI", "false"))
            && haskey(ENV, "ACTIONS_ID_TOKEN_REQUEST_TOKEN")
            && haskey(ENV, "ACTIONS_ID_TOKEN_REQUEST_URL"))
        quote
            response = $HTTP.get($(ENV["ACTIONS_ID_TOKEN_REQUEST_URL"]),
                query=["audience" => $(esc(audience))],
                headers=["Authorization" => "bearer " * $(ENV["ACTIONS_ID_TOKEN_REQUEST_TOKEN"])])
            # the token is in subfield value https://blog.alexellis.io/deploy-without-credentials-using-oidc-and-github-actions/
            $JSON3.read(response.body).value
        end
    # Fallback with Dummy Value
    else
        quote
            payload = Dict(
                "iss" => "http://www.example.com/",
                "sub" => "/env/YOUR_ENV/github.com/YOUR_ORGANIZATION/YOUR_REPO/PATH/TO/WORKFLOW",
                "aud" => $(esc(audience)),
                "exp" => 1536080651,
                "iat" => 1535994251,
            )
            # for details see https://github.com/tanmaykm/JWTs.jl/issues/22
            ".$(JWT(; payload))."
        end
    end
end

"""
    @authorize_aws(role_arn; audience="")

Assume role via web identity. How to define such a role can be found here
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html#cli-configure-role-oidc

CAUTION: Please note that th semicolon is really important! `@authorize_aws(role_arn, audience="myaudience")` won't work as of now.
"""
macro authorize_aws(args...)
    mydateformat = Dates.dateformat"yyyymmdd\THHMMSS\Z"
    # we define a function in a macro, so that we can use @get_jwt macro (which needs the location)
    # as well as use `renew`` argument, which requires a function
    @gensym _authorize_aws
    esc(quote
        function $_authorize_aws(role_arn; audience="", role_session::Union{AbstractString,Nothing}=nothing)
            if isnothing(role_session)
                role_session = $AWS._role_session_name(
                    "jolincloud-role-",
                    basename(role_arn),
                    "-" * $Dates.format($Dates.now($Dates.UTC), $mydateformat),
                )
            end
            # we need to be cautious that @get_jwt is called with the same __source__
            web_identity = $(Expr(:macrocall, var"@get_jwt", __source__, :audience))

            response = $AWS.AWSServices.sts(
                "AssumeRoleWithWebIdentity",
                Dict(
                    "RoleArn" => role_arn,
                    "RoleSessionName" => role_session,  # Required by AssumeRoleWithWebIdentity
                    "WebIdentityToken" => web_identity,
                );
                aws_config=$AWS.AWSConfig(; creds=nothing),
                feature_set=$AWS.FeatureSet(; use_response_type=true),
            )
            dict = parse(response)
            role_creds = dict["AssumeRoleWithWebIdentityResult"]["Credentials"]
            assumed_role_user = dict["AssumeRoleWithWebIdentityResult"]["AssumedRoleUser"]

            return $AWS.global_aws_config(creds=$AWS.AWSCredentials(
                role_creds["AccessKeyId"],
                role_creds["SecretAccessKey"],
                role_creds["SessionToken"],
                assumed_role_user["Arn"];
                expiry=$Dates.DateTime(rstrip(role_creds["Expiration"], 'Z')),
                renew=() -> $_authorize_aws(role_arn; audience, role_session).credentials,
            ))
        end
        $(Expr(:call, _authorize_aws, args...))
    end)
end

# TODO add Azure, Google Cloud and HashiCorp

macro take_repeatedly!(expr)
	quote
		let
			channel = $(esc(expr))
			_update, set_update = @use_state(take!(channel))
			@use_task([channel]) do
				inner_channel = channel
                while isopen(inner_channel)
                    try
                        for update in inner_channel
                            set_update(update)
                        end
                    catch ex
                        if isa(ex, EOFError)
                            @warn "got this weird EOFError" exception=(ex, catch_backtrace())
                            Core.println("got this weird EOFError")
                            sleep(1)
                        else
                            rethrow()
                        end
                    end
                end
			end
			_update
		end
	end
end

@eval JolinPluto @cont function _free_symbols(expr::Expr)
    for arg in expr.args
        if isa(arg, Symbol)
            isdefined(Main, arg) || cont(arg)

        elseif isa(arg, Expr)
			if arg.head ∈ (:function, :->)
				call = arg.args[1]
				body = arg.args[2]

				func_args = if isa(call, Symbol)
					(call,)
				elseif call.head === :tuple
					call.args
				elseif call.head === :call
					call.args[2:end]
				end

				foreach(_free_symbols(body)) do sym
					sym ∈ func_args || cont(sym)
				end
			elseif arg.head === :ref
				# this is indexing, where the symbols :end and :begin have special meaning
				foreach(_free_symbols(arg)) do sym
					sym ∈ (:begin, :end) || cont(sym)
				end
			else
            	foreach(cont, _free_symbols(arg))
			end
        end
    end
end

macro repeaton(
    nexttime_from_now,
	expr,
	sleeptime_from_diff = diff -> max(div(diff,2), Dates.Millisecond(5))
)
    # if the first argument is a function, we interpret the args reversed
    if Meta.isexpr(nexttime_from_now, (:->, :function))
		time_as_arg = true
        nexttime = esc(expr)
		runme = esc(nexttime_from_now)
	else
		time_as_arg = false
		nexttime = esc(nexttime_from_now)
		if Meta.isexpr(expr, (:->, :function))
			# if function syntax is used explicitly we assume that the user knows about the functionality
			runme = esc(expr)
		else
			runme = esc(Expr(:->, gensym("t"), expr))
		end
	end
    deps = esc.(unique!(vcat(
        collect(_free_symbols(runme)),
        collect(_free_symbols(nexttime)),
    )))

	quote
		let
			_update, set_update = @use_state($runme($Dates.now()))
			@use_task([$(deps...)]) do
                while true
                    try
                        nexttime = $nexttime
                        diff = nexttime - $Dates.now()
                        while diff > $Dates.Millisecond(0)
                            sleep($(esc(sleeptime_from_diff))(diff))
                            diff = nexttime - $Dates.now()
                        end
                        set_update($runme(nexttime))
                    catch ex
                        if isa(ex, EOFError)
                            @warn "got this weird EOFError" exception=(ex, catch_backtrace())
                            Core.println("weird EOFError")
                            sleep(1)
                        else
                            rethrow()
                        end
                    end
                end
			end
			_update
		end
	end
end


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
    channel = @Channel(10) do ch
        for i in 1:10
            put!(ch, i)
            sleep(1)
        end
    end

Like normal `Channel`, with the underlying task being interrupted
as soon as the Pluto cell is deleted.
"""
macro Channel(args...)
    # TODO support keyword argumnts
    if is_running_in_pluto_process()
        quote
            taskref = Ref{Task}()
            chnl = Channel($(map(esc, args)...); taskref=taskref)
            register_cleanup_fn = $(Main.PlutoRunner.GiveMeRegisterCleanupFunction())
            register_cleanup_fn() do
                if !istaskdone(taskref[])
                    try
                        Base.schedule(taskref[], InterruptException(), error=true)
                    catch error
                        nothing
                    end
                end
            end
            chnl
        end
    else
        # just create a plain channel without cleanup
        quote
            Channel($(map(esc, args)...))
        end
    end
end


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
function embedLargeHTML(rawpagedata; kwargs...)
    if is_running_in_pluto_process()
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
end  # module
