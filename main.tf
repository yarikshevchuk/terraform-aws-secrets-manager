resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

# subnets

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "Public subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.1.0/24"

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
    cidr_block = var.local_ip
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