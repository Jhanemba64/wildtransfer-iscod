terraform {
  required_version = ">= 1.5"

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
