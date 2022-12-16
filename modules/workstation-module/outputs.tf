output "ip_address" {
  value = aws_instance.this.private_ip
}

output "ip_address_public" {
  value = aws_instance.this.public_ip
}