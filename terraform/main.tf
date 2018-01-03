variable "region" {
  default = "us-east-1"
}

provider "aws" {
  region = "${var.region}"
  profile = "javadoc.zone"
}

terraform {
  backend "s3" {
    bucket = "jdz-terraform-state"
    key    = "jdz/state"
    region = "us-east-1"
    profile = "javadoc.zone"
  }
}

data "aws_caller_identity" "current" {}
