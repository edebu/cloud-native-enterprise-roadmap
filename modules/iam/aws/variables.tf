# modules/iam/aws/variables.tf — Stub (PR 5.4)

variable "role_name" { type = string; default = "devops-role" }
variable "display_name" { type = string; default = "" }
variable "assume_role_principals" { type = list(string); default = ["ec2.amazonaws.com"] }
variable "managed_policy_arns" { type = list(string); default = [] }
variable "tags" { type = map(string); default = {} }
