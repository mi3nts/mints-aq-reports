using AWS, AWSS3

struct AnonymousOSN <:AbstractAWSConfig
    endpoint::String
end

struct NoCredentials end

AWS.region(osn::AnonymousOSN) = ""
AWS.credentials(osn::AnonymousOSN) = NoCredentials()
AWS.check_credentials(c::NoCredentials) = c
AWS.sign!(osn::AnonymousOSN, ::AWS.Request) = nothing

function AWS.generate_service_url(osn::AnonymousOSN, service::String, resource::String)
    service == "s3" || throw(ArgumentError("Can only handle s3 requests to GCS"))
    return string(osn.endpoint, resource)
end




