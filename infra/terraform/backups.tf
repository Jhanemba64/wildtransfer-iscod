# Copie des sauvegardes hors du serveur.
# Le serveur n'a aucune clé AWS : le bucket accepte uniquement des dépôts (PutObject), uniquement depuis
# l'IP du serveur. Un serveur compromis ne peut ni lire, ni lister, ni supprimer les sauvegardes.
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "backups" {
  bucket = "${var.name}-backups-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Versionnement : un dépôt ne peut pas écraser une sauvegarde existante
resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Rétention : 30 jours
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expiration-30-jours"
    status = "Enabled"
    filter {}
    expiration {
      days = 30
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "backups" {
  bucket     = aws_s3_bucket.backups.id
  depends_on = [aws_s3_bucket_public_access_block.backups]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DepotDepuisLeServeurUniquement"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.backups.arn}/*"
      Condition = { IpAddress = { "aws:SourceIp" = "${aws_eip.server.public_ip}/32" } }
    }]
  })
}
