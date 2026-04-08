terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary region
provider "aws" {
  region = "us-east-1"
}

# Secondary region ; DR site
provider "aws" {
  alias  = "secondary"
  region = "eu-west-1"
}
