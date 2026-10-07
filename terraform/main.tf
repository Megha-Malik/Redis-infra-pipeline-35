terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# --- VPC & Networking ---
resource "aws_vpc" "redis_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "redis-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.redis_vpc.id

  tags = {
    Name = "redis-igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.redis_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = {
    Name = "redis-public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.redis_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.region}a"

  tags = {
    Name = "redis-private-subnet"
  }
}

resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "redis-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "redis-nat-gateway"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.redis_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "redis-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.redis_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "redis-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# --- Security Groups (Base) ---
resource "aws_security_group" "bastion_sg" {
  name_prefix        = "bastion-sg"
  description = "Allow SSH to Bastion"
  vpc_id      = aws_vpc.redis_vpc.id

  tags = {
    Name = "bastion-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "redis_private_sg" {
  name_prefix        = "redis-private-sg"
  description = "Allow SSH & Redis from Bastion Subnet"
  vpc_id      = aws_vpc.redis_vpc.id

  tags = {
    Name = "redis-private-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Bastion Security Group Rules ---
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_bastion" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_egress_bastion" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- Private Redis Security Group Rules ---
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_from_bastion" {
  security_group_id            = aws_security_group.redis_private_sg.id
  referenced_security_group_id = aws_security_group.bastion_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_redis_from_bastion" {
  security_group_id            = aws_security_group.redis_private_sg.id
  referenced_security_group_id = aws_security_group.bastion_sg.id
  from_port                    = 6379
  ip_protocol                  = "tcp"
  to_port                      = 6379
}

resource "aws_vpc_security_group_egress_rule" "allow_all_egress_redis" {
  security_group_id = aws_security_group.redis_private_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- Dynamic AMIs ---
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# --- EC2 Instances ---
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.key_name

  tags = {
    Name = "Bastion-Host"
    Role = "bastion"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "al2023_redis" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.redis_private_sg.id]
  key_name               = var.key_name

  tags = {
    Name = "Redis-AL2023-Server"
    Role = "redis-node"
    OS   = "amazon_linux"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "ubuntu_redis" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.redis_private_sg.id]
  key_name               = var.key_name

  tags = {
    Name = "Redis-Ubuntu-Server"
    Role = "redis-node"
    OS   = "ubuntu"
  }

  lifecycle {
    create_before_destroy = true
  }
}