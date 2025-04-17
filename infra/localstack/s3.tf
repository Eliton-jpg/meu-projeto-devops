

resource "aws_s3_bucket" "staging_bucket" {
  bucket = var.s3_bucket_name
  
}


resource "aws_s3_bucket_acl" "staging_bucket_acl" {
  bucket = aws_s3_bucket.staging_bucket.id
  acl    = "private" # ACL padrão
}
