# Minimum Terraform version required to run this project
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws" # Official AWS provider from the Terraform registry
      version = "~> 5.0"        # Any 5.x version ; locked to avoid breaking changes from 6.x
    }
  }
}

# AWS provider configuration ; defines which region all resources will be created in
provider "aws" {
  region = "us-east-1"
}
