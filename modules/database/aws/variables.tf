# modules/database/aws/variables.tf — Stub (PR 5.4)

variable "instance_name" { type = string; default = "" }
variable "region" { type = string; default = "" }
variable "db_name" { type = string; default = "productdb" }
variable "db_user" { type = string; default = "appuser" }
variable "db_password" { type = string; sensitive = true; default = "" }
variable "db_instance_class" { type = string; default = "db.t3.micro" }
variable "db_subnet_group_name" { type = string; default = "" }
variable "subnet_ids" { type = list(string); default = [] }
variable "vpc_id" { type = string; default = "" }
variable "allowed_security_group_id" { type = string; default = "" }
variable "deletion_protection" { type = bool; default = false }
variable "tags" { type = map(string); default = {} }
