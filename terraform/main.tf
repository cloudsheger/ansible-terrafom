terraform {
    backend "s3" {
        bucket = "workstation-repo"
        key    = "workstation-repo/workstation"

        region = "us-east-1"
        dynamodb_endpoint = "workstation"
    }
}

terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "3.72.0"
        }
    }
}

provider "aws" {
    region = "us-east-1"
}

locals {
    tags = {
        ManagedBy = "Terraform"
        Manual    = "No"
        Supports  = "cloudsheger"
    }
    public_key = file("id_rsa.pub")
    clap_on    = "0 4 @ @ 1-5 @"
    clap_off   = "20:00"
}

data "aws_ami" "this" {
    most_recent = true

    filter {
        name   = "name"
        values = [var.ami_name]
    }

    owners = ["083407797149"]
}

data "aws_vpc" "this" {
    tags = {
        Name   = "cloudcasts-staging-vpc"

    }
}

data "aws_subnet" "this" {
    tags = {
        Name   = "cloudcasts-staging-public-subnet"
        Subnet = "us-east-1c-3"
    }
}

data "aws_security_group" "this" {
    vpc_id = data.aws_vpc.this.id
    name   = "cloudcasts-staging-public-sg"
}

#data "aws_iam_instance_profile" "this" {
#  name = "INSTANCE_EXAMPLE"
#}

#resource "aws_key_pair" "this" {
 #   key_name   = var.user_name
 #   public_key = local.public_key
 #   tags       = local.tags
#}

resource "aws_instance" "this" {
    ami           = data.aws_ami.this.id
    instance_type = var.instance_type
    key_name      = "box12022"
   #subnet_id     = data.aws_subnet.this.id
    #map_public_ip_on_launch = true

    #iam_instance_profile   = data.aws_iam_instance_profile.this.name
    #vpc_security_group_ids = [data.aws_security_group.this.id]

    root_block_device {
        delete_on_termination = true
        encrypted             = false
        volume_size           = 160
        volume_type           = "gp2"
    }

    user_data = templatefile(
        "user_data.sh",
        {
            user_name  = var.user_name
            public_key = local.public_key
        }
    )

    tags = merge(local.tags, {
        "Name"         = "Developer Workstation for ${var.user_name}"
        "Username"     = var.user_name
        "CLAP_ON"      = local.clap_on
        "CLAP_OFF"     = local.clap_off
    })
}
