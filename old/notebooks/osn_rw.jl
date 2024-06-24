using AWS, AWSS3
using CSV, DataFrames


endpoint = "https://ncsa.osn.xsede.org"
bucket = "/ees230012-bucket01"
creds  = AWSCredentials(;profile= "ES230012_John_Waczak")


struct OSNConfig <: AbstractAWSConfig
    endpoint::String
    creds
end

AWS.region(c::OSNConfig) = ""
AWS.credentials(c::OSNConfig) = c.creds


function AWS.generate_service_url(osn::OSNConfig, service::String, resource::String)
    service == "s3" || throw(ArgumentError("Can only handle s3 requests to OSN"))
    return string(osn.endpoint, resource)
end


AWS.global_aws_config(OSNConfig(endpoint, creds))

p = S3Path("s3://ees230012-bucket01/central-node-8/2023/2023/05/02/", config=global_aws_config());

df_paths = []

for (root,dirs,files) ∈ walkdir(p)
    for f ∈ files
        push!(df_paths, joinpath(root, f))
    end
end

CSV.File(S3Path(df_paths[1], config=global_aws_config())) |> DataFrame


