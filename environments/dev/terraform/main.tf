module "network" {
  source = "../../../modules/network"

  project_id          = var.project_id
  region              = var.region
  network_name        = "dev-enterprise-vpc"
  public_subnet_cidr  = "10.10.1.0/24"
  private_subnet_cidr = "10.10.2.0/24"
}