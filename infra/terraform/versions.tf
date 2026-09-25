terraform {
  required_version = ">= 1.10"

  # État partagé dans S3 (versionné, chiffré, privé), avec verrou contre les modifications simultanées
  backend "s3" {
    bucket       = "wildtransfer-tfstate-971598352115"
    key          = "wildtransfer/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Identifiants : profil AWS CLI (ex. export AWS_PROFILE=meditrack)
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "wildtransfer"
      ManagedBy = "terraform"
    }
  }
}
