terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0, < 5.0"
    }
  }
  backend "s3" {
    bucket  = "bhcrc-tfstate"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    profile = "terraform"

  }
}

# I created this module with SSO in mind instead of using
# access keys to avoid the use of long term credentials.
# When you log into the CLI with SSO replace "profile"
# with the name of your own.

provider "aws" {
  region  = "us-east-1"
  profile = "terraform"
}
/*
#----------------------------Remote-State-Bucket----------------------------#

resource "aws_s3_bucket" "tf_state_bucket" {
  bucket = "bhcrc-tf-state"
}

resource "aws_s3_bucket_acl" "tf_state_bucket_acl" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "tf_state_bucket_block_public_access" {
  bucket = aws_s3_bucket.tf_state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tf_state_bucket_versioning" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
*/

# Required to use these modules are:
# Route 53 Zone
# ACM Certificate

module "frontend" {
  source = "./modules/frontend"
  depends_on = [
    module.backend
  ]
}

module "backend" {
  source = "./modules/backend"
}
