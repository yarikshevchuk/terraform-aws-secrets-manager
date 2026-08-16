# Ubuntu ami
data "aws_ami" "ubuntu" {
  most_recent = true
  region = var.region

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["amazon"]
}

# Trust policy
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Secrets manager access policy
data "aws_iam_policy_document" "secrets_access" {
  statement {
    sid = "AllowSecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [aws_secretsmanager_secret.secret.arn]
  }

  statement {
    sid = "AllowKMSDecrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.secret_key.arn]
  }
}

# availability zones
data "aws_availability_zones" "available" {
  state = "available"
}