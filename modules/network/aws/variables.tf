# modules/network/aws/variables.tf
# Stub — full implementation in PR 5.2.

variable "region" {
  type    = string
  default = ""
}

variable "network_name" {
  type    = string
  default = ""
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.20.2.0/24"
}

variable "tags" {
  type    = map(string)
  default = {}
}
