terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_vpc" "gymtracker" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "gymtracker-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.gymtracker.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "gymtracker-public-subnet"
  }
}

resource "aws_internet_gateway" "gymtracker" {
  vpc_id = aws_vpc.gymtracker.id

  tags = {
    Name = "gymtracker-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.gymtracker.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gymtracker.id
  }

  tags = {
    Name = "gymtracker-public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "frontend" {
  name        = "gymtracker-frontend-sg"
  description = "Allow HTTP traffic to the Gym Tracker frontend"
  vpc_id      = aws_vpc.gymtracker.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gymtracker-frontend-sg"
  }
}

resource "aws_instance" "frontend" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  associate_public_ip_address = true

  tags = {
    Name = "gymtracker-frontend"
  }
}