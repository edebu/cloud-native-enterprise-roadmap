# modules/kubernetes/aws/variables.tf — Stub (PR 5.3)

variable "cluster_name" { type = string; default = "" }
variable "region" { type = string; default = "" }
variable "vpc_id" { type = string; default = "" }
variable "subnet_ids" { type = list(string); default = [] }
variable "node_instance_type" { type = string; default = "t3.medium" }
variable "tags" { type = map(string); default = {} }
