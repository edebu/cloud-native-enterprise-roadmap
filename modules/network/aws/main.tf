# modules/network/aws/main.tf
#
# AWS Network — placeholder stub for PR 5.1.
# Full implementation is delivered in PR 5.2.
#
# This file exists to make the top-level modules/network/main.tf structurally
# valid when cloud_provider = "aws" is referenced. The AWS module is not
# invoked by any active environment in PR 5.1.

# PR 5.2 will implement:
#   - aws_vpc
#   - aws_subnet (public + private)
#   - aws_internet_gateway
#   - aws_nat_gateway + aws_eip
#   - aws_route_table + aws_route_table_association
#   - aws_security_group (deny SSH, allow internal)
