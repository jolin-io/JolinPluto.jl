"""
    @get_jwt
    @get_jwt "exampleaudience"

Creates a JSON Web Token which can be used for authentication at common cloud providers.

On cloud.jolin.io the token will be issued and signed by cloud.jolin.io,
on Github Actions (used for automated tests), a respective github token is returned.
"""
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
    get_jwt()
    get_jwt("exampleaudience")

Creates a JSON Web Token which can be used for authentication at common cloud providers.

On cloud.jolin.io the token will be issued and signed by cloud.jolin.io,
on Github Actions (used for automated tests), a respective github token is returned.
"""
function get_jwt(audience="")
    # Jolin Cloud
    if parse(Bool, get(ENV, "JOLIN_CLOUD", "false"))
        serviceaccount_token = readchomp("/var/run/secrets/kubernetes.io/serviceaccount/token")
        path = Main.PlutoRunner.notebook_path[]
        project_dir = readchomp(`$(git()) -C $(dirname(path)) rev-parse --show-toplevel`)
        @assert startswith(path, project_dir) "invalid workflow location"
        workflowpath = path[length(project_dir)+2:end]

        response = HTTP.get("http://jolin-workspace-server-jwts.jolin-workspace-server/request_jwt",
            query=["serviceaccount_token" => serviceaccount_token,
                   "workflowpath" => workflowpath,
                   "audience" => audience])
        JSON3.read(response.body).token
    # Github Actions
    elseif (parse(Bool, get(ENV, "CI", "false"))
            && haskey(ENV, "ACTIONS_ID_TOKEN_REQUEST_TOKEN")
            && haskey(ENV, "ACTIONS_ID_TOKEN_REQUEST_URL"))
        response = HTTP.get(ENV["ACTIONS_ID_TOKEN_REQUEST_URL"],
            query=["audience" => audience],
            headers=["Authorization" => "bearer " * ENV["ACTIONS_ID_TOKEN_REQUEST_TOKEN"]])
        # the token is in subfield value https://blog.alexellis.io/deploy-without-credentials-using-oidc-and-github-actions/
        JSON3.read(response.body).value
    # Fallback with Dummy Value
    else
        payload = Dict(
            "iss" => "http://www.example.com/",
            "sub" => "/env/YOUR_ENV/github.com/YOUR_ORGANIZATION/YOUR_REPO/PATH/TO/WORKFLOW",
            "aud" => audience,
            "exp" => 1536080651,
            "iat" => 1535994251,
        )
        # for details see https://github.com/tanmaykm/JWTs.jl/issues/22
        jwt = JWT(; payload)
        ".$jwt."
    end
end


"""
    @authorize_aws(role_arn; audience="")

Assume role via web identity. How to define such a role can be found here
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html#cli-configure-role-oidc

CAUTION: Please note that the semicolon is really important! `@authorize_aws(role_arn, audience="myaudience")` won't work as of now.
"""
macro authorize_aws end

"""
    authorize_aws(role_arn; audience="")

Assume role via web identity. How to define such a role can be found here
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html#cli-configure-role-oidc

CAUTION: Please note that the semicolon is really important! `@authorize_aws(role_arn, audience="myaudience")` won't work as of now.
"""
function authorize_aws end

# TODO add Azure, Google Cloud and HashiCorp
