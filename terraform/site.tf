resource "aws_s3_bucket" "site" {
  bucket_prefix = "jdz-${terraform.workspace}-site"
  acl    = "public-read"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "site_policy" {
  bucket = "${aws_s3_bucket.site.id}"
  policy =<<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": "*"},
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.site.id}/*"
    }
  ]
}
POLICY
}

variable "objects" {
  default = [["index.html", "text/html", "/index"], ["add.html", "text/html", "/add"], ["css/site.css", "text/css", "/css/site.css"]]
}

resource "aws_s3_bucket_object" "site_object" {
  count      = "${length(var.objects)}"
  key        = "${element(var.objects[count.index], 2)}"
  bucket     = "${aws_s3_bucket.site.id}"
  source     = "../site/.build/${element(var.objects[count.index], 0)}"
  content_type = "${element(var.objects[count.index], 1)}"
  etag         = "${md5(file("../site/.build/${element(var.objects[count.index], 0)}"))}"
}

resource "aws_api_gateway_resource" "site_object" {
  rest_api_id = "${aws_api_gateway_rest_api.jdz_api.id}"
  parent_id = "${aws_api_gateway_rest_api.jdz_api.root_resource_id}"
  path_part = "{proxy+}"
}

resource "aws_api_gateway_integration" "site_integration" {
  rest_api_id              = "${aws_api_gateway_rest_api.jdz_api.id}"
  resource_id              = "${aws_api_gateway_resource.site_object.id}"
  http_method              = "${aws_api_gateway_method.site_method.http_method}"
  type                     = "HTTP_PROXY"
  integration_http_method  = "GET"
  uri                      = "http://${aws_s3_bucket.site.id}.s3.amazonaws.com/{proxy}"
  passthrough_behavior     = "WHEN_NO_MATCH"
  request_parameters       = { "integration.request.path.proxy" = "method.request.path.proxy" }
}

resource "aws_api_gateway_method" "site_method" {
  rest_api_id                   = "${aws_api_gateway_rest_api.jdz_api.id}"
  resource_id                   = "${aws_api_gateway_resource.site_object.id}"
  http_method                   = "GET"
  authorization                 = "NONE"
  request_parameters            = {"method.request.path.proxy" = true}
}

# Root

resource "aws_api_gateway_integration" "site_root_integration" {
  rest_api_id              = "${aws_api_gateway_rest_api.jdz_api.id}"
  resource_id              = "${aws_api_gateway_rest_api.jdz_api.root_resource_id}"
  http_method              = "${aws_api_gateway_method.site_root_method.http_method}"
  type                     = "HTTP_PROXY"
  integration_http_method  = "GET"
  uri                      = "http://${aws_s3_bucket.site.id}.s3.amazonaws.com/index"
  passthrough_behavior     = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_method" "site_root_method" {
  rest_api_id                   = "${aws_api_gateway_rest_api.jdz_api.id}"
  resource_id                   = "${aws_api_gateway_rest_api.jdz_api.root_resource_id}"
  http_method                   = "GET"
  authorization                 = "NONE"
}

