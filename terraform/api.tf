resource "aws_iam_role" "cloudwatch" {
  name = "global_cloudwatch_role_jdz_${terraform.workspace}"
  assume_role_policy = "${file("policies/cloudwatch-assume-role.json")}"
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "global_cloudwatch_role_policy"
  role = "${aws_iam_role.cloudwatch.id}"
  policy = "${file("policies/cloudwatch-policy.json")}"
}

resource "aws_api_gateway_account" "jdz_api" {
  cloudwatch_role_arn = "${aws_iam_role.cloudwatch.arn}"
}

resource "aws_api_gateway_rest_api" "jdz_api" {
  name = "jdz-${terraform.workspace}-api"
  description = "API for javadoc.zoom"
}

resource "aws_api_gateway_method_settings" "method_settings" {
  rest_api_id = "${aws_api_gateway_rest_api.jdz_api.id}"
  stage_name  = "${aws_api_gateway_deployment.deployment.stage_name}"
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

# By creating this explicitly, we make sure it's deleted when the stack is destroyed
resource "aws_cloudwatch_log_group" "api_gateway" {
  name = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.jdz_api.id}/v1"
}
