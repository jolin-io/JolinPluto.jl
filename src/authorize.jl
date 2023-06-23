
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
