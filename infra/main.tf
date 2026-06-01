terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  # Remote state, isolated per environment via the key.
  backend "s3" {} # configured at init time (see CD workflow)
}

provider "aws" { region = var.aws_region }

locals { name = "triage-agent-${var.env}" }

# Execution role for the Lambda (least privilege: just logging here)
resource "aws_iam_role" "lambda" {
  name = "${local.name}-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow", Action = "sts:AssumeRole",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# The function — note it points at the SAME prebuilt artifact in S3.
resource "aws_lambda_function" "agent" {
  function_name = local.name
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "app.handler.lambda_handler"
  memory_size   = var.memory_mb
  timeout       = 10

  s3_bucket = var.artifact_bucket
  s3_key    = var.artifact_key

  environment { variables = { STAGE = var.env } }
}

# HTTP API in front of the function
resource "aws_apigatewayv2_api" "http" {
  name          = local.name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.agent.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "triage" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /triage"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.agent.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}