# modules/secrets/aws/variables.tf — Stub (PR 5.4)

variable "secret_id" { type = string; default = "" }
variable "secret_value" { type = string; sensitive = true; default = "" }
variable "tags" { type = map(string); default = {} }
