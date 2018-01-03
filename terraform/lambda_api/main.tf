variable "name" {
  description = "name of the lambda"
}

variable "code_bucket" {
  description = "S3 bucket containing lambda codebases"
}

variable "code_key" {
  description = "S3 bucket key of a zipfile containing a codebase"
}

variable "handler" {
  description = "entrypoint handler function for the lambda"
}

variable "region" {
  description = "AWS region"
}

variable "api" {
  description = "The associated aws_api_gateway_rest_api resource"
}

variable "api_root" {
  description = "The root resource of the associated aws_api_gateway_rest_api"
}

variable "path" {
  description = "The URL path for this endpoint"
}

variable "prefix_path" {
  description = "path segment added before the primary segment path"
  default = "false"
}

variable "method" {
  description = "the HTTP method"
}

variable "stage" {
  description = "the API Gateway stage name"
}

variable "aws_account" {
  description = "the AWS account id"
}

variable "lambda_env" {
  description = "map containing environment variable sto pass to lambda"
  type = "map"
  default = {FOOBAR = 32}
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.name}-lambda-role"
  assume_role_policy = "${file("${path.module}/policies/lambda-assume-role.json")}"
}

resource "aws_iam_role_policy" "lambda_role_policy" {
  name = "jdz-${terraform.workspace}-lambda-policy"
  role = "${aws_iam_role.lambda_role.id}"
  policy = "${file("${path.module}/policies/lambda-policy.json")}"
}

resource "aws_lambda_function" "fn" {
  function_name = "${var.name}"
  s3_bucket = "${var.code_bucket}"
  s3_key = "${var.code_key}"
  handler = "${var.handler}"
  role = "${aws_iam_role.lambda_role.arn}"
  runtime = "nodejs6.10"
  timeout = 30

  environment {
    variables = "${var.lambda_env}"
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name = "/aws/lambda/${aws_lambda_function.fn.function_name}"
}

resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.fn.arn}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  # source_arn = "arn:aws:execute-api:region:account-id:api-id/stage/METHOD_HTTP_VERB/Resource-path"
  # source_arn = "arn:aws:execute-api:${var.region}:${var.aws_account}:${var.api}/${var.stage}/${var.method}/${var.path}"
  source_arn = "arn:aws:execute-api:${var.region}:${var.aws_account}:${var.api}/${var.stage}/${var.method}/*"

}

resource "aws_api_gateway_resource" "prefix" {
  count = "${var.prefix_path == "false" ? "0" : "1"}"
  rest_api_id = "${var.api}"
  parent_id = "${var.api_root}"
  path_part = "${var.prefix_path}"
}

resource "aws_api_gateway_resource" "resource" {
  rest_api_id = "${var.api}"
  parent_id = "${var.prefix_path == "false" ? var.api_root : join(" ", aws_api_gateway_resource.prefix.*.id) }"
  path_part = "${var.path}"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id = "${var.api}"
  resource_id = "${aws_api_gateway_resource.resource.id}"
  http_method = "${var.method}"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id = "${var.api}"
  resource_id = "${aws_api_gateway_resource.resource.id}"
  http_method = "${aws_api_gateway_method.method.http_method}"
  type = "AWS_PROXY"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.region}:${var.aws_account}:function:${aws_lambda_function.fn.function_name}/invocations"
  integration_http_method = "POST"
}

output "endpoint" {
  value = "${var.method} https://${var.api}.execute-api.${var.region}.amazonaws.com/${var.stage}/${var.path}"
}
