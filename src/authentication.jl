import HTTP
import JSON3
using JWTs: JWT
using Git: git

"""
    authenticate_token()
    authenticate_token("exampleaudience")

Creates a JSON Web Token which can be used for authentication at common cloud providers.

On cloud.jolin.io the token will be issued and signed by cloud.jolin.io,
on Github Actions (used for automated tests), a respective github token is returned.
"""
function authenticate_token(audience="")
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
        return JSON3.read(response.body).token

    # Github Actions
    elseif (parse(Bool, get(ENV, "CI", "false"))
            && haskey(ENV, "ACTIONS_ID_TOKEN_REQUEST_TOKEN")
            && haskey(ENV, "ACTIONS_ID_TOKEN_REQUEST_URL"))
        response = HTTP.get(ENV["ACTIONS_ID_TOKEN_REQUEST_URL"],
            query=["audience" => audience],
            headers=["Authorization" => "bearer " * ENV["ACTIONS_ID_TOKEN_REQUEST_TOKEN"]])
        # the token is in subfield value https://blog.alexellis.io/deploy-without-credentials-using-oidc-and-github-actions/
        return JSON3.read(response.body).value
    
    # using a specific environment variable to set the token from the outside for local development purposes
    elseif haskey(ENV, "JOLIN_JWT_FALLBACK")
        return ENV["JOLIN_JWT_FALLBACK"]

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
        return ".$jwt."
    end
end


"""
    authenticate_aws(role_arn; audience="")

Assume role via web identity. How to define such a role can be found here
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html#cli-configure-role-oidc
"""
function authenticate_aws end

# TODO add Azure, Google Cloud and HashiCorp
