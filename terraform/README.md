How to run the script

```
export WS=
terraform apply -auto-approve -lock-timeout=600s -no-color -var user_name=$WS
```
How to destroy the script

terraform destroy -var user_name=$WS


Terraform debuging ref : 

https://spacelift.io/blog/terraform-debug