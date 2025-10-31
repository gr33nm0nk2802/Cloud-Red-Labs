terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
}

provider "aws" {
  profile = "default"   # change profile 
  region  = var.region
}

data "aws_caller_identity" "current" {}

# Initial Access: lambda
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

data "aws_iam_policy_document" "lambda_list_and_assume" {
  # ListRoles (must be "*")
  statement {
    sid       = "AllowListRoles"
    effect    = "Allow"
    actions   = ["iam:ListRoles"]
    resources = ["*"]
  }

  # Read trust/meta for lab roles
  statement {
    sid     = "AllowGetRoleLab"
    effect  = "Allow"
    actions = ["iam:GetRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-*"
    ]
  }

  # Inspect policies on lab roles (managed + inline)
  statement {
    sid    = "AllowListPoliciesOnLabRoles"
    effect = "Allow"
    actions = [
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-*"
    ]
  }

  statement {
    sid     = "AllowGetInlinePoliciesOnLabRoles"
    effect  = "Allow"
    actions = ["iam:GetRolePolicy"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-*"
    ]
  }

  statement {
    sid     = "AllowReadLabManagedPolicies"
    effect  = "Allow"
    actions = ["iam:GetPolicy", "iam:GetPolicyVersion"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.name_prefix}-*"
    ]
  }
  
  statement {
    sid    = "AllowDescribeRDSInstances"
    effect = "Allow"
    actions = [
      "rds:DescribeDBInstances",
      "rds:DescribeDBClusters",
      "rds:DescribeDBSnapshots",
      "rds:DescribeDBSubnetGroups",
      "rds:DescribeDBParameterGroups",
      "rds:DescribeDBSecurityGroups",
      "rds:DescribeEvents",
      "rds:DescribeDBEngineVersions",
      "rds:DescribeOptionGroups",
      "rds:ListTagsForResource",
      "rds:DescribeCertificates"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowTaggingRead"
    effect = "Allow"
    actions = [
      "rds:ListTagsForResource"
    ]
    resources = ["*"]
  }

  # Allow assuming the S3 reader role
  statement {
    sid     = "AllowAssumeS3ReaderRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-s3-reader"
    ]
  }
}

resource "aws_iam_policy" "lambda_list_and_assume" {
  name   = "${var.name_prefix}-lambda-list-and-assume"
  policy = data.aws_iam_policy_document.lambda_list_and_assume.json
}

resource "aws_iam_role_policy_attachment" "attach_lambda_list_and_assume" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_list_and_assume.arn
}

resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_lambda_function" "app" {
  function_name    = "${var.name_prefix}-lambda"
  filename         = var.zip_path
  handler          = "app.handler" # change to match your entry point
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_role.arn
  timeout          = 10
  memory_size      = 256
  source_code_hash = filebase64sha256("${var.zip_path}")
}

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.app.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

output "api_url" {
  description = "Public base URL"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

resource "aws_s3_bucket" "internal" {
  bucket        = "${var.name_prefix}-internal-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_object" "flag2" {
  bucket  = aws_s3_bucket.internal.bucket
  key     = "flag2.txt"
  content = "${var.flag2}"
}

data "aws_iam_policy_document" "s3_reader_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.lambda_role.arn]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "s3_reader_role" {
  name               = "${var.name_prefix}-s3-reader"
  assume_role_policy = data.aws_iam_policy_document.s3_reader_trust.json
}

data "aws_iam_policy_document" "s3_reader_access" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.internal.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.internal.arn}/*"]
  }
}

resource "aws_iam_policy" "s3_reader_policy" {
  name   = "${var.name_prefix}-s3-reader-policy"
  policy = data.aws_iam_policy_document.s3_reader_access.json
}

resource "aws_iam_role_policy_attachment" "s3_reader_attach" {
  role       = aws_iam_role.s3_reader_role.name
  policy_arn = aws_iam_policy.s3_reader_policy.arn
}

resource "aws_iam_user" "secret_reader_user" {
  name = "${var.name_prefix}-secret-reader"
  tags = {
    purpose = "lab-long-term-secret-reader"
  }
}

resource "aws_iam_access_key" "secret_reader_key" {
  user = aws_iam_user.secret_reader_user.name
}

resource "aws_s3_object" "secret_reader_creds" {
  bucket  = aws_s3_bucket.internal.bucket
  key     = "secret_reader_creds.txt"
  content = <<EOT
  AWS_ACCESS_KEY_ID=${aws_iam_access_key.secret_reader_key.id}
  AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.secret_reader_key.secret}
  AWS_DEFAULT_REGION=${var.region}
  EOT
}

resource "aws_ssm_parameter" "flag3" {
  name        = "/${var.name_prefix}/flag3"
  description = "Flag 3 - only secret-reader may read"
  type        = "SecureString"
  value       = "${var.flag3}"
  overwrite   = true
}

data "aws_iam_policy_document" "secret_reader_ssm_only" {
  statement {
    sid    = "AllowReadFlag3Only"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParameterHistory"
    ]
    resources = [aws_ssm_parameter.flag3.arn, "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.name_prefix}/db/*"]
  }
  statement {
    sid       = "AllowDescribeParameters"
    effect    = "Allow"
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "secret_reader_ssm_only" {
  name   = "${var.name_prefix}-secret-reader-ssm-only"
  policy = data.aws_iam_policy_document.secret_reader_ssm_only.json
}

resource "aws_iam_user_policy_attachment" "attach_secret_reader_ssm_only" {
  user       = aws_iam_user.secret_reader_user.name
  policy_arn = aws_iam_policy.secret_reader_ssm_only.arn
}

resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.name_prefix}/db/password"
  description = "Lab DB password"
  type        = "SecureString"
  value       = random_password.db.result
  overwrite   = true
}

resource "aws_ssm_parameter" "db_username" {
  name        = "/${var.name_prefix}/db/username"
  description = "Lab DB username (non-secret)"
  type        = "String"
  value       = "ctfadmin"
  overwrite   = true
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "lab_a" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.50.10.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name_prefix}-subnet-a"
  }
}

resource "aws_subnet" "lab_b" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.50.11.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name_prefix}-subnet-b"
  }
}

resource "aws_route_table" "lab_public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = {
    Name = "${var.name_prefix}-rt-public"
  }
}

resource "aws_route_table_association" "lab_a" {
  subnet_id      = aws_subnet.lab_a.id
  route_table_id = aws_route_table.lab_public.id
}

resource "aws_route_table_association" "lab_b" {
  subnet_id      = aws_subnet.lab_b.id
  route_table_id = aws_route_table.lab_public.id
}

resource "aws_db_subnet_group" "rds" {
  name        = "${var.name_prefix}-db-subnets"
  description = "Subnets for lab RDS"
  subnet_ids  = [
     aws_subnet.lab_a.id,
     aws_subnet.lab_b.id,
  ]
  tags        = { Name = "${var.name_prefix}-db-subnets" }
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Allow MySQL for lab"
  vpc_id      =  aws_vpc.lab.id

  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # lab only; tighten to /32 or jump host in prod
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-rds-sg" }
}

resource "aws_db_instance" "rds" {
  identifier        = "${var.name_prefix}-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  username = "ctfadmin"
  password = random_password.db.result

  # Create a DB/schema up-front
  db_name = "ctf"

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  publicly_accessible    = true

  backup_retention_period = 0
  deletion_protection     = false
  skip_final_snapshot     = true
  apply_immediately       = true
}

data "aws_region" "current" {}

resource "null_resource" "seed_db" {

  triggers = {
    rds_endpoint = aws_db_instance.rds.address
    final_flag   = var.flag4
  }

  depends_on = [
    aws_db_instance.rds,
    aws_ssm_parameter.db_username,
    aws_ssm_parameter.db_password,
    aws_security_group.rds,
    aws_db_subnet_group.rds
  ]

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-o", "pipefail", "-c"]

    command = <<-EOT
      set -eu
      REGION="ap-south-1"

      echo "[seed] fetching DB creds from SSM in $${REGION}"
      DBUSER=$(aws --region "$${REGION}" ssm get-parameter --name '/${var.name_prefix}/db/username' --query 'Parameter.Value' --output text)
      DBPASS=$(aws --region "$${REGION}" ssm get-parameter --with-decryption --name '/${var.name_prefix}/db/password' --query 'Parameter.Value' --output text)

      echo "[seed] waiting for MySQL @ ${aws_db_instance.rds.address}:3306 ..."
      for i in $(seq 1 60); do
        mysql -h ${aws_db_instance.rds.address} -P 3306 -u "$${DBUSER}" -p"$${DBPASS}" -e 'SELECT 1' >/dev/null 2>&1 && break || { echo "[seed] MySQL not ready yet..."; sleep 10; }
      done

      echo "[seed] seeding (idempotent)..."
      mysql -h ${aws_db_instance.rds.address} -P 3306 -u "$${DBUSER}" -p"$${DBPASS}" <<'SQL'
      CREATE DATABASE IF NOT EXISTS ctf;
      USE ctf;
      CREATE TABLE IF NOT EXISTS flags (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(64) UNIQUE,
        value TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      INSERT INTO flags (name, value)
        VALUES ('final_flag', '${var.flag4}')
        ON DUPLICATE KEY UPDATE value = VALUES(value);
      SQL
      echo "✅ Final flag ensured in ctf.flags"
    EOT
  }
}