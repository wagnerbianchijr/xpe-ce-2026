resource "aws_s3_bucket" "upload" {
  bucket = local.bucket_name

  tags = local.tags
}

resource "aws_s3_bucket_notification" "upload_trigger" {
  bucket = aws_s3_bucket.upload.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.metadata_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
