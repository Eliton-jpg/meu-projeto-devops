

variable "s3_bucket_name" {
  description = "Nome do bucket S3 para staging (deve ser único globalmente se não usar path style)"
  type        = string
  default     = "meu-local-staging-bucket-1a2b3c" 
}

variable "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB para staging"
  type        = string
  default     = "local-staging-app-data"
}
