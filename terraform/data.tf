data "template_file" "init" {
        template = file("user_data.sh")
        vars = {
            user_name  = var.user_name
            //public_key = file("id_rsa.pub")
            public_key = file("${path.module}/pub_keys/id_rsa.pub")
        }
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