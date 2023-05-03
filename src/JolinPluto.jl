module JolinPluto

# we use macros for everything to release mental load here
export @get_jwt, @authorize_aws, @take_repeatedly!, @repeaton, @output_below

using Dates
using HTTP, JSON3
# TODO conditional dependency?
using AWS
using HypertextLiteral

macro get_jwt(audience="")
    serviceaccount_token = readchomp("/var/run/secrets/kubernetes.io/serviceaccount/token")
    project_dir = dirname(Base.current_project())
    path = split(String(__source__.file),"#==#")[1]
    @assert startswith(path, project_dir) "invalid workflow location"
    workflowpath = path[length(project_dir)+2:end]
    quote
        response = $HTTP.get("http://jolin-workspace-server-jwts.default/request_jwt",
            query=["serviceaccount_token" => $serviceaccount_token,
                    "workflowpath" => $workflowpath,
                    "audience" => $(esc(audience))])
        $JSON3.read(response.body).token
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
            web_identity = $JolinPluto.@get_jwt(audience)

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
                renew=() -> $_authorize_aws(role_arn; audience, role_session),
            ))
        end
        $(Expr(:call, _authorize_aws, args...))
    end)
end

# TODO add Azure, Google Cloud and HashiCorp

macro take_repeatedly!(channel)
	special_pluto_expr = PlutoRunner.GiveMeRerunCellFunction()
	quote
		result = take!($channel)
		rerun_cell = $special_pluto_expr
		rerun_cell()
		result
	end
end

macro repeaton(
	nexttime_from_now,
	expr,
	sleeptime_from_diff = diff -> max(div(diff,2), Dates.Millisecond(5))
)
	special_pluto_expr = PlutoRunner.GiveMeRerunCellFunction()
	# for updates why this macroexpand workaround see
	# https://discourse.julialang.org/t/error-using-sync-async-within-macro-help-is-highly-appreciated/94080
	_needs_macroexpand_ = quote
		nexttime = $nexttime_from_now()
		@sync @async begin
			diff = nexttime - $Dates.now()
			while diff > $Dates.Millisecond(0)
				sleep($sleeptime_from_diff(diff))
				diff = nexttime - $Dates.now()
			end
		end
		result = $expr
		rerun_cell = $special_pluto_expr
		rerun_cell()
		result
	end
	macroexpand(__module__, _needs_macroexpand_)
end


macro output_below()
    result = @htl """
        <style>
        pluto-notebook[swap_output] pluto-cell {
            display: flex;
            flex-direction: column;
        }
        pluto-notebook[swap_output] pluto-cell pluto-output {
            order: 1;
        }
        pluto-notebook[swap_output] pluto-cell pluto-runarea {
            top: 5px;
            /* placing it left to the cell options: */
            /* right: 14px; */
            /* placing it right to the cell options: */
            right: -80px;
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

end  # module
