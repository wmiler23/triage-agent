variable "env"            { type = string }                 # dev | integration | staging | prod
variable "aws_region"     { type = string  default = "us-east-1" }
variable "artifact_bucket"{ type = string }                 # S3 bucket holding built zips
variable "artifact_key"   { type = string }                 # e.g. triage-agent-<gitsha>.zip
variable "memory_mb"      { type = number  default = 256 }  # scaled per env