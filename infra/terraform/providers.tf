provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile == "" ? null : var.aws_profile
}

terraform {
  backend "s3" {
    bucket       = "781659100115-togglemaster-tfstate"
    key          = "techchallenger/fase3/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
  }
}
