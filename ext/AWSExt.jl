module AWSExt
import JolinPluto, AWS
using Dates

# this way works to overload a macro https://github.com/JuliaLang/julia/issues/15838
import JolinPluto.@authorize_aws
import JolinPluto.authorize_aws


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
            web_identity = $(Expr(:macrocall, JolinPluto.var"@get_jwt", __source__, :audience))

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
            dict = $JolinPluto.parse(response)
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

function authorize_aws(args...)
    mydateformat = Dates.dateformat"yyyymmdd\THHMMSS\Z"
    # we define a function in a macro, so that we can use @get_jwt macro (which needs the location)
    # as well as use `renew`` argument, which requires a function
    function _authorize_aws(role_arn; audience="", role_session::Union{AbstractString,Nothing}=nothing)
        if isnothing(role_session)
            role_session = AWS._role_session_name(
                "jolincloud-role-",
                basename(role_arn),
                "-" * Dates.format(Dates.now(Dates.UTC), mydateformat),
            )
        end
        # we need to be cautious that @get_jwt is called with the same __source__
        web_identity = JolinPluto.get_jwt(audience)

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
        dict = JolinPluto.parse(response)
        role_creds = dict["AssumeRoleWithWebIdentityResult"]["Credentials"]
        assumed_role_user = dict["AssumeRoleWithWebIdentityResult"]["AssumedRoleUser"]

        return AWS.global_aws_config(creds=AWS.AWSCredentials(
            role_creds["AccessKeyId"],
            role_creds["SecretAccessKey"],
            role_creds["SessionToken"],
            assumed_role_user["Arn"];
            expiry=Dates.DateTime(rstrip(role_creds["Expiration"], 'Z')),
            renew=() -> _authorize_aws(role_arn; audience, role_session).credentials,
        ))
    end
    _authorize_aws(args...)
end

end  # module