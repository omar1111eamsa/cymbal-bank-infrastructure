# Our own key for the app secrets: decrypting needs kms:Decrypt on THIS key
# (second lock after secretsmanager:GetSecretValue)
resource "aws_kms_key" "secrets" {
  description             = "Cymbal Bank secrets (Secrets Manager)"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  # Key policy: the account keeps control; IAM policies then grant the use (e.g. ESO)
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AccountAdmin"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

# Fixed name: the ephemeral layer finds the key by alias (no ARN copy-paste)
resource "aws_kms_alias" "secrets" {
  name          = "alias/cymbal-bank-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

data "aws_caller_identity" "current" {}
