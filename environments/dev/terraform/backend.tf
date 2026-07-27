terraform {
  backend "gcs" {
    bucket = "cn-er-terraform-state-bucket-dev"
    prefix = "env/dev"
  }
}