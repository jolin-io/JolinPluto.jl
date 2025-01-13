module AWSExt
import Jolin, AWS, JSON3
using Dates

function Jolin.authenticate_aws(args...)
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
        # we need to be cautious that @get_jwt is called with the same __source__
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
    _authenticate_aws(args...)
end

end  # module