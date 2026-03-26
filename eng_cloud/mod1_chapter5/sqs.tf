resource "aws_sqs_queue" "processing_queue" {
  name                       = "${var.project_name}-processing-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  tags = local.tags
}

resource "aws_sqs_queue_policy" "allow_lambda" {
  queue_url = aws_sqs_queue.processing_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.processing_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_lambda_function.metadata_processor.arn
          }
        }
      }
    ]
  })
}
