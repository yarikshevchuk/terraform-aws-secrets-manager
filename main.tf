resource "aws_vpc" "main" {
  cidr_block       = "172.16.0.0/16"
  instance_tenancy = "default"
  
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "main"
  }
}

resource "aws_vpc_endpoint" "sm" {
  vpc_id = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.public.id,
    aws_subnet.private.id
  ]

  security_group_ids = [
    aws_security_group.vpc_endpoint_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "Secrets manager vpc endpoint"
  }
}

# subnets

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id

  cidr_block = "172.16.0.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "Public subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.main.id

  cidr_block = "172.16.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "Private subnet"
  }
}

# gateways
# internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Internet gateway"
  }
}

# nat gateway with eip
resource "aws_eip" "eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "Elastic IP"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "Nat gateway"
  }
}

# Route tables 
# public route table
resource "aws_route_table" "public_rtb" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = var.any_ip
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public route table"
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public_rtb.id
  subnet_id      = aws_subnet.public.id
}

#private route table
resource "aws_route_table" "private_rtb" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = var.any_ip
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private route table"
  }
}

resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private_rtb.id
  subnet_id      = aws_subnet.private.id
}

# security groups
# public security group with ingress and egress rules
resource "aws_security_group" "public_sg" {
  name   = "public-sg"
  description = "Allow ssh connection from local IP, all http inbound traffic and all outbound traffic"

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Public security group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_rule_pub" {
  description = "Security group rule allowing incoming ssh traffic from local IP"

  security_group_id = aws_security_group.public_sg.id

  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_ipv4   = var.local_ip

}

resource "aws_vpc_security_group_ingress_rule" "http_rule_pub" {
  description = "Security group rule allowing all incoming http traffic"

  security_group_id = aws_security_group.public_sg.id

  ip_protocol = "tcp"
  from_port = 80
  to_port = 80
  cidr_ipv4 = var.any_ip
}

resource "aws_vpc_security_group_egress_rule" "egress_rule_pub" {
  description = "Security group rule allowing any outgoing traffic"

  security_group_id = aws_security_group.public_sg.id

  ip_protocol = -1
  cidr_ipv4 = var.any_ip
}

# private security group with igress and egress rules
resource "aws_security_group" "private_sg" {
  name = "private-sg"
  description = "Allow only ssh traffic from public-sg"

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Private security group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_rule_prvt" {
  description = "Allow ssh connection from public-sg"

  security_group_id = aws_security_group.private_sg.id
  referenced_security_group_id = aws_security_group.public_sg.id

  ip_protocol = "tcp"
  from_port = 22
  to_port = 22
}

resource "aws_vpc_security_group_ingress_rule" "app_rule_prvt" {
  description = "Allow access from public SG"

  security_group_id =  aws_security_group.private_sg.id
  referenced_security_group_id = aws_security_group.public_sg.id

  ip_protocol = "tcp"
  from_port = 8080
  to_port = 8080
}

resource "aws_vpc_security_group_egress_rule" "egress_rule_prvt" {
  description = "Allow outbound access"

  security_group_id = aws_security_group.private_sg.id
  ip_protocol =  -1
  cidr_ipv4 = var.any_ip
}

# vpc endpoint security group
resource "aws_security_group" "vpc_endpoint_sg" {
  name = "vpc-endpoint-sg"
  description = "Allow HTTPS inbound traffic from EC2 to Secrets Manager"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "VPC endpoint security group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http_rule_endpoint" {
  description = "Allow http inbound traffic"

  security_group_id = aws_security_group.vpc_endpoint_sg.id
  referenced_security_group_id = aws_security_group.public_sg.id

  ip_protocol = "tcp"
  from_port = 443
  to_port = 443
}

# KMS key & secrets manager

resource "aws_kms_key" "secret_key" {
  description = "Custom secret KMS key"
  deletion_window_in_days = 7
  enable_key_rotation = true

  tags = {
    Name = "Secrets manager KMS key"
  }
}


resource "aws_secretsmanager_secret" "secret" {
  name = "secret-key"
  kms_key_id = aws_kms_key.secret_key.arn

  tags = {
    Name = "Secret key"
  }
}

resource "aws_secretsmanager_secret_version" "secret_version" {
  secret_id = aws_secretsmanager_secret.secret.id
  secret_string = var.secret_value
}


# IAM role and policies

# Trust policy
resource "aws_iam_role" "ec2_secrets_role" {
  name = "ec2-secrets-manager-role"
  assume_role_policy =  data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "EC2 Secrets Manager role"
  } 
}

# Secrets manager access policy
resource "aws_iam_policy" "secrets_access_policy" {
  name = "ec2-secrets-access-policy"
  description = "Allows EC2 to read secrets and decrypt keys using KMS"
  policy = data.aws_iam_policy_document.secrets_access.json
}

resource "aws_iam_role_policy_attachment" "secrets_access_attachment" {
  role = aws_iam_role.ec2_secrets_role.name
  policy_arn = aws_iam_policy.secrets_access_policy.arn
}

# Instance profile to pass to aws Instance

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "aws-ec2-instance-profile"
  role = aws_iam_role.ec2_secrets_role.name
}

# AWS EC2 instance 

resource "aws_key_pair" "main" {
  key_name   = "aws-ec2-key"
  public_key = file("~/.ssh/aws_ec2_key.pub")
}

resource "aws_instance" "main" {
  ami = data.aws_ami.ubuntu.id
  region = var.region
  instance_type = var.ec2_instance_type
  key_name = aws_key_pair.main.key_name

  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  associate_public_ip_address = true

  user_data_base64 = filebase64("${path.module}/user-data.sh")

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
}