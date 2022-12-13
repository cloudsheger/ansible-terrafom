resource "aws_instance" "this" {
    ami           = data.aws_ami.this.id
    instance_type = var.instance_type
    key_name      = var.key
    user_data     = data.template_file.init.template
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

    tags = {
      "Name" =  "Developer Workstation for ${var.user_name}"
      "Environment" = "Cloudsheger"
      "Username"     = var.user_name
      "clap_on"    = "0 4 @ @ 1-5 @"
      "clap_off"   = "20:00"
    }
}
