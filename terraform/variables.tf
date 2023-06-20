variable "user_name" {
    type        = string
    description = "The name of the workstation's user"
}

variable "ami_name" {
    type        = string
    description = "The AMI to base the workstation on"
    default     = "cloudsheger-workstation-20230609"
}

variable "key" {
    type        = string
    description = "private key name"
    default     = "box12022"
}

variable "instance_type" {
  description = "Instance type t2.micro"
  type        = string
  default     = "t2.micro"
 
  validation {
   condition     = can(regex("^[Tt][2-3].(nano|micro|small)", var.instance_type))
   error_message = "Invalid Instance Type name. You can only choose - t2.nano,t2.micro,t2.small"
 }
}