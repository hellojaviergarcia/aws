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

# Primary provider ; all resources without an explicit provider attribute use this one
provider "aws" {
  region = "us-east-1" # Primary region where the main bucket lives
}

# Secondary provider ; used exclusively for resources that declare provider = aws.replica
# Terraform supports multiple instances of the same provider via aliases,
# which is the standard pattern for cross-region deployments
provider "aws" {
  alias  = "replica"   # Referenced as aws.replica in resource blocks
  region = "eu-west-1" # Secondary region where the replica bucket lives
}
