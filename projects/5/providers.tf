terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary region ; where the main bucket lives
provider "aws" {
  region = "us-east-1"
}

# Secondary region ; where the replica bucket lives
provider "aws" {
  alias  = "replica"
  region = "eu-west-1"
}
