provider "aws" {
  region = "eu-north-1"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_amplify_app" "my_amplify_app" {
  name         = "StudyNotesProject"
  repository   = "https://github.com/kwolny1/cloud_computing_project"  # URL del repositorio
  platform     = "WEB"  # Esto es para una aplicación web (React)
  environment_variables = {
    "REACT_APP_ENV" = "production"
  }
  build_spec = <<BUILD_SPEC
version: 1.0
frontend:
  phases:
    preBuild:
      commands:
        - npm install
    build:
      commands:
        - npm run build
  artifacts:
    baseDirectory: /build
    files:
      - '**/*'
  cache:
    paths:
      - node_modules/**/*
BUILD_SPEC

  oauth_token = "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"
}



resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_dynamodb_comprehend_policy"
  description = "Allow Lambda to use DynamoDB and Comprehend"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.study_notes.arn
      },
      {
        Action = [
          "comprehend:DetectKeyPhrases"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_dynamodb_table" "study_notes" {
  name         = "StudyNotes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "note_id"

  attribute {
    name = "note_id"
    type = "S"
  }
}

resource "aws_lambda_function" "summarize_notes_lambda" {
  function_name = "summarize_notes_lambda"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda_function.lambda_handler"
  filename      = "lambda_function.zip"
  timeout       = 10

  environment {
    variables = {
      DYNAMO_TABLE = aws_dynamodb_table.study_notes.name
    }
  }
}

resource "aws_apigatewayv2_api" "api" {
  name          = "notes-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.summarize_notes_lambda.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /summarize"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.summarize_notes_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

#GET
resource "aws_apigatewayv2_route" "get_note_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /note"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# PUT
resource "aws_apigatewayv2_route" "update_note_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "PUT /note"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# DELETE 
resource "aws_apigatewayv2_route" "delete_note_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "DELETE /note"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}