######### Generic stuff

variable "stage" {
  default = "v1"
}

resource "aws_s3_bucket" "lambdas" {
  bucket_prefix = "jdz-${terraform.workspace}-lambdas"
  acl    = "private"
  force_destroy = true
}

data "archive_file" "codebase" {
  type  = "zip"
  source_dir = "../lambdas"
  output_path = ".build/codebase.zip"
}

resource "aws_s3_bucket_object" "codebase" {
  bucket = "${aws_s3_bucket.lambdas.id}"
  key    = "codebase-${data.archive_file.codebase.output_md5}.zip"
  source = "${data.archive_file.codebase.output_path}"
}

######### Modularized calls

module "add" {
  source = "./lambda_api"

  name = "jdz-${terraform.workspace}-add"
  handler = "add.handler"
  path = "add"
  method = "POST"

  stage = "${var.stage}"
  code_bucket = "${aws_s3_bucket.lambdas.id}"
  code_key = "${aws_s3_bucket_object.codebase.key}"
  region = "${var.region}"
  api = "${aws_api_gateway_rest_api.jdz_api.id}"
  api_root = "${aws_api_gateway_rest_api.jdz_api.root_resource_id}"
  aws_account = "${data.aws_caller_identity.current.account_id}"

  lambda_env = {
    CLASSES_TABLE = "${aws_dynamodb_table.classes.name}"
    HOSTS_TABLE = "${aws_dynamodb_table.hosts.name}"
  }
}

module "search" {
  source = "./lambda_api"

  name = "jdz-${terraform.workspace}-search"
  handler = "search.handler"
  path = "search"
  method = "GET"

  stage = "${var.stage}"
  code_bucket = "${aws_s3_bucket.lambdas.id}"
  code_key = "${aws_s3_bucket_object.codebase.key}"
  region = "${var.region}"
  api = "${aws_api_gateway_rest_api.jdz_api.id}"
  api_root = "${aws_api_gateway_rest_api.jdz_api.root_resource_id}"
  aws_account = "${data.aws_caller_identity.current.account_id}"

  lambda_env = {
    CLASSES_TABLE = "${aws_dynamodb_table.classes.name}"
    HOSTS_TABLE = "${aws_dynamodb_table.hosts.name}"
  }
}

module "go" {
  source = "./lambda_api"

  name = "jdz-${terraform.workspace}-go"
  handler = "go.handler"
  prefix_path = "go"
  path = "{className}"
  method = "GET"

  stage = "${var.stage}"
  code_bucket = "${aws_s3_bucket.lambdas.id}"
  code_key = "${aws_s3_bucket_object.codebase.key}"
  region = "${var.region}"
  api = "${aws_api_gateway_rest_api.jdz_api.id}"
  api_root = "${aws_api_gateway_rest_api.jdz_api.root_resource_id}"
  aws_account = "${data.aws_caller_identity.current.account_id}"

  lambda_env = {
    CLASSES_TABLE = "${aws_dynamodb_table.classes.name}"
    HOSTS_TABLE = "${aws_dynamodb_table.hosts.name}"
  }
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    "module.add",
    "module.search",
    "module.go",
    "aws_api_gateway_integration.site_integration",
    "aws_api_gateway_integration.site_root_integration"
  ]
  rest_api_id = "${aws_api_gateway_rest_api.jdz_api.id}"
  stage_name = "${var.stage}"
}


output "url" {
  value = "https://${aws_api_gateway_rest_api.jdz_api.id}.execute-api.${var.region}.amazonaws.com/${var.stage}"
}
