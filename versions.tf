terraform {
    required_providers {
        aws = {
            souce = "hashicorp/aws"
            version = "~> 6.0"
        }
    }
}

provider "aws" {
    region = var.region
}