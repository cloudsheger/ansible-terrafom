terraform {
  backend "s3" {
    bucket = "workstation-repo"
    key    = "workstation-repo/workstation"

    region            = "us-east-1"
    dynamodb_endpoint = "workstation"
  }
}