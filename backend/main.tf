terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0, < 5.0"
    }
  }
  backend "s3" {
    bucket  = "bhcrc-tfstate"
    key     = "backend.tfstate"
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

#-------------------------DynamoDB-Table--------------------------------------------------#

resource "aws_dynamodb_table" "visitor_count" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = var.hash_key

  attribute {
    name = var.hash_key
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "count" {
  table_name = aws_dynamodb_table.visitor_count.name
  hash_key   = var.hash_key

  item = <<ITEM
{
  "id"   : {"S": "0"},
  "count": {"N": "101"}
}
ITEM

  lifecycle {
    ignore_changes = [
      item
    ]
  }
}

#---------------------------Lambda---------------------------------------------------------#

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

data "aws_iam_policy_document" "dynamodb_access" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      aws_dynamodb_table.visitor_count.arn
    ]
  }
}

resource "aws_iam_role_policy_attachment" "dynamodb_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_lambda_function" "count" {
  filename      = "lambda/count.zip"
  function_name = "count"
  handler       = "count.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
}

resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowMyDemoAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.count.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*"
}

#------------------------API-Gateway--------------------------------------------------------#

resource "aws_api_gateway_rest_api" "rest_api" {
  name = var.api_name
  put_rest_api_mode = "overwrite"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "count" {
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "count"
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
}

resource "aws_api_gateway_method" "OPTIONS" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_rest_api.rest_api.root_resource_id
  http_method = aws_api_gateway_method.OPTIONS.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "OPTIONS" {
  rest_api_id          = aws_api_gateway_rest_api.rest_api.id
  resource_id          = aws_api_gateway_rest_api.rest_api.root_resource_id
  http_method          = aws_api_gateway_method.OPTIONS.http_method
  type                 = "MOCK"
  passthrough_behavior = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{ \"statusCode\": 200 }"
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_rest_api.rest_api.root_resource_id
  http_method = aws_api_gateway_method.OPTIONS.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [
    aws_api_gateway_method.OPTIONS
  ]
}

resource "aws_api_gateway_method" "GET" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.count.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "GET" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.count.id
  http_method             = "GET"
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.count.invoke_arn
}

resource "aws_api_gateway_method_response" "get_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.count.id
  http_method = aws_api_gateway_method.GET.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "POST" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.count.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "POST" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.count.id
  http_method             = "POST"
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.count.invoke_arn
}

resource "aws_api_gateway_method_response" "post_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.count.id
  http_method = aws_api_gateway_method.POST.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.count.id,
      aws_api_gateway_method.GET.id,
      aws_api_gateway_method.POST.id,
      aws_api_gateway_method.OPTIONS.id,
      aws_api_gateway_integration.GET.id,
      aws_api_gateway_integration.POST.id,
      aws_api_gateway_integration.OPTIONS.id,
  ]))}

  depends_on = [
    aws_api_gateway_account.cloudwatch_logs
  ]
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = "prod"
  deployment_id = aws_api_gateway_deployment.deployment.id

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.log_group.arn
    format = jsonencode({
      requestId = "$context.requestId"
      apiId = "$context.apiId"
      resourcePath = "$context.resourcePath"
      httpMethod = "$context.httpMethod"
      status = "$context.status"
      responseLength = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_api_gateway_account" "cloudwatch_logs" {
  cloudwatch_role_arn = aws_iam_role.cloudwatch_logs_role.arn
}

resource "aws_api_gateway_method_settings" "cloudwatch" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    data_trace_enabled = true
    logging_level   = "ERROR"
  }
}

#-----------------------------CloudWatch------------------------------------------------------#

resource "aws_iam_role" "cloudwatch_logs_role" {
  name = "APIGatewayCloudWatchLogsRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
  role       = aws_iam_role.cloudwatch_logs_role.name
}

resource "aws_cloudwatch_log_group" "log_group" {
    name = "api-gateway-log-group"
    retention_in_days = 30
}