module AWSExt
import JolinPluto, AWS, JSON3
using Dates

"""
    authenticate_aws("role_arn_string";
        audience="optional audience string",
        role_session="optional session string for role to assume")

Assume role via web identity. How to define such a role can be found here
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html#cli-configure-role-oidc

Returns a `AWS.global_aws_config` object, which however is usually not needed, the `AWS.jl` client is immediately authenticated.

Includes automatic re-authentication if underlying token expired.

# Example

This method gets automatically included when using AWS.
```julia
using AWS
ENV["AWS_DEFAULT_REGION"] = "eu-central-1"
role_arn = "arn:aws:iam::123456789:role/test-role-to-assume-from-jolin"
authenticate_aws(role_arn; audience="awsaudience")
```

now you can immediately use AWS services 
```julia
AWS.@service SSM
param = SSM.get_parameter("my-credentials", Dict("WithDecryption" => true))
```
"""
function JolinPluto.authenticate_aws(role_arn; audience="", role_session::Union{AbstractString,Nothing}=nothing)
    mydateformat = Dates.dateformat"yyyymmdd\THHMMSS\Z"
    # we define a function in a macro, so that we can use @get_jwt macro (which needs the location)
    # as well as use `renew`` argument, which requires a function
    function _authenticate_aws(role_arn; audience="", role_session::Union{AbstractString,Nothing}=nothing)
        if isnothing(role_session)
            role_session = AWS._role_session_name(
                "jolincloud-role-",
                basename(role_arn),
                "-" * Dates.format(Dates.now(Dates.UTC), mydateformat),
            )
        end
        web_identity = Jolin.jolin_token(audience)

        response = AWS.AWSServices.sts(
            "AssumeRoleWithWebIdentity",
            Dict(
                "RoleArn" => role_arn,
                "RoleSessionName" => role_session,  # Required by AssumeRoleWithWebIdentity
                "WebIdentityToken" => web_identity,
            );
            aws_config=AWS.AWSConfig(; creds=nothing),
            feature_set=AWS.FeatureSet(; use_response_type=true),
        )
        dict = JSON3.read(response)
        role_creds = dict["AssumeRoleWithWebIdentityResult"]["Credentials"]
        assumed_role_user = dict["AssumeRoleWithWebIdentityResult"]["AssumedRoleUser"]

        return AWS.global_aws_config(creds=AWS.AWSCredentials(
            role_creds["AccessKeyId"],
            role_creds["SecretAccessKey"],
            role_creds["SessionToken"],
            assumed_role_user["Arn"];
            expiry=Dates.DateTime(rstrip(role_creds["Expiration"], 'Z')),
            renew=() -> _authenticate_aws(role_arn; audience, role_session).credentials,
        ))
    end
    _authenticate_aws(role_arn; audience, role_session)
end

end  # module