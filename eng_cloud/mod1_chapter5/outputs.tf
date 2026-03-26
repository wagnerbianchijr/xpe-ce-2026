output "s3_bucket_name" {
  description = "Name of the S3 upload bucket"
  value       = aws_s3_bucket.upload.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 upload bucket"
  value       = aws_s3_bucket.upload.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.metadata_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.metadata_processor.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS processing queue"
  value       = aws_sqs_queue.processing_queue.url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS processing queue"
  value       = aws_sqs_queue.processing_queue.arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.workers.name
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.workers.id
}
