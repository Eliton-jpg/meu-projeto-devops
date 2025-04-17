

output "s3_bucket_id" {
  description = "ID (nome) do bucket S3 criado"
  value       = aws_s3_bucket.staging_bucket.id
}

output "dynamodb_table_name_output" {
  description = "Nome da tabela DynamoDB criada"
  value       = aws_dynamodb_table.staging_table.name
}
