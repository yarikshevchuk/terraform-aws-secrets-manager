resource "aws_vpc" "main" {
  cidr_block       = "172.16.0.0/16"
  instance_tenancy = "default"

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

  tags = {
    Name = "Public subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.main.id

  cidr_block = "172.16.1.0/24"

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