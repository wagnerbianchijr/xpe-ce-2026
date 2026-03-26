locals {
  bucket_name = md5(plantimestamp())

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
