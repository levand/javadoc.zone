resource "aws_dynamodb_table" "classes" {
  name           = "jdz-classes-${terraform.workspace}"
  read_capacity  = 5
  write_capacity = 100
  hash_key       = "name"
  range_key      = "host"

  attribute {
    name = "name"
    type = "S"
  }

  attribute {
    name = "host"
    type = "S"
  }

  lifecycle {
    ignore_changes = ["read_capacity", "write_capacity"]
  }
}

resource "aws_dynamodb_table" "hosts" {
  name           = "jdz-hosts-${terraform.workspace}"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "host"

  attribute {
    name = "host"
    type = "S"
  }

  // version
  // maven artifact group
  // maven artifact name
  // date added

  lifecycle {
    ignore_changes = ["read_capacity", "write_capacity"]
  }
}




# Disable autoscaling until a bug is resolved: https://github.com/terraform-providers/terraform-provider-aws/issues/2750

/*
resource "aws_iam_role" "dynamo_autoscaling" {
  name = "dynamo_autoscaling_role_jdz_${terraform.workspace}"
  assume_role_policy = "${file("policies/dynamo-autoscaling-assume-role.json")}"
}

resource "aws_iam_role_policy" "dynamo_autoscaling" {
  name = "dynamo_autoscaling_role_policy_jdz_${terraform.workspace}"
  role = "${aws_iam_role.dynamo_autoscaling.id}"
  policy = "${file("policies/dynamo-autoscaling-policy.json")}"
}

resource "aws_appautoscaling_target" "class_table_reads" {
  max_capacity       = 100
  min_capacity       = 1
  resource_id        = "table/${aws_dynamodb_table.classes.name}"
  role_arn           = "${aws_iam_role.dynamo_autoscaling.arn}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}


resource "aws_appautoscaling_policy" "class_table_read_policy" {
  name = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.class_table_reads.resource_id}"
  policy_type = "TargetTrackingScaling"
  resource_id = "${aws_appautoscaling_target.class_table_reads.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.class_table_reads.scalable_dimension}"
  service_namespace  = "${aws_appautoscaling_target.class_table_reads.service_namespace}"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    target_value = 70
  }
}


/*
resource "aws_appautoscaling_target" "class_table_writes" {
  depends_on         = ["aws_iam_role.dynamo_autoscaling"]
  max_capacity       = 100
  min_capacity       = 1
  resource_id        = "table/${aws_dynamodb_table.classes.name}"
  role_arn           = "${aws_iam_role.dynamo_autoscaling.arn}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "class_table_write_policy" {
  name = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.class_table_writes.resource_id}"
  policy_type = "TargetTrackingScaling"
  resource_id = "${aws_appautoscaling_target.class_table_writes.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.class_table_writes.scalable_dimension}"
  service_namespace  = "${aws_appautoscaling_target.class_table_writes.service_namespace}"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    target_value = 70
  }
}
*/

