# modules/registry/aws/variables.tf — Stub (PR 5.4)

variable "repository_id" { type = string; default = "app-images" }
variable "description" { type = string; default = "" }
variable "image_tag_mutability" { type = string; default = "MUTABLE" }
variable "tags" { type = map(string); default = {} }
