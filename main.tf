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

resource "aws_subnet" "backend" {
  vpc_id     = aws_vpc.gymtracker.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "gymtracker-backend-subnet"
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
  user_data_replace_on_change = true

    user_data = <<-EOF
    #!/bin/bash

    apt-get update
    apt-get install -y nginx

    cat > /var/www/html/index.html <<'HTML'
    ${file("${path.module}/frontend/index.html")}
    HTML

    cat > /etc/nginx/sites-available/default <<'NGINX'
    server {
        listen 80 default_server;
        listen [::]:80 default_server;

        root /var/www/html;
        index index.html;

        location / {
            try_files $uri $uri/ =404;
        }

        location /api/ {
            proxy_pass http://${aws_instance.backend.private_ip}:5000/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
    NGINX

    nginx -t
    systemctl enable nginx
    systemctl restart nginx
    EOF
}

resource "aws_security_group" "backend" {
  name        = "gymtracker-backend-sg"
  description = "Allow Flask traffic from the frontend"
  vpc_id      = aws_vpc.gymtracker.id

  ingress {
    description     = "Flask API from frontend"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gymtracker-backend-sg"
  }
}

resource "aws_instance" "backend" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.backend.id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  associate_public_ip_address = true

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash

    apt-get update
    apt-get install -y python3 python3-pip python3-flask python3-psycopg2 python3-flask-cors

    mkdir -p /opt/gymtracker

    cat > /opt/gymtracker/app.py <<'PYTHON'
    ${file("${path.module}/backend/app.py")}
    PYTHON

    cat > /etc/systemd/system/gymtracker.service <<SERVICE
    [Unit]
    Description=Gym Tracker Flask Backend
    After=network.target

    [Service]
    WorkingDirectory=/opt/gymtracker
    Environment="DB_HOST=${aws_db_instance.gymtracker.address}"
    Environment="DB_PASSWORD=${var.db_password}"
    ExecStart=/usr/bin/python3 /opt/gymtracker/app.py
    Restart=always

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable gymtracker
    systemctl start gymtracker
  EOF

  tags = {
    Name = "gymtracker-backend"
  }
}

resource "aws_route_table_association" "backend" {
  subnet_id      = aws_subnet.backend.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "database_a" {
  vpc_id            = aws_vpc.gymtracker.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "gymtracker-database-subnet-a"
  }
}

resource "aws_subnet" "database_b" {
  vpc_id            = aws_vpc.gymtracker.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "gymtracker-database-subnet-b"
  }
}

resource "aws_db_subnet_group" "gymtracker" {
  name = "gymtracker-db-subnet-group"

  subnet_ids = [
    aws_subnet.database_a.id,
    aws_subnet.database_b.id
  ]

  tags = {
    Name = "gymtracker-db-subnet-group"
  }
}

resource "aws_security_group" "database" {
  name        = "gymtracker-database-sg"
  description = "Allow PostgreSQL traffic from the backend"
  vpc_id      = aws_vpc.gymtracker.id

  ingress {
    description     = "PostgreSQL from backend"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gymtracker-database-sg"
  }
}

variable "db_password" {
  description = "Password for the Gym Tracker database"
  type        = string
  sensitive   = true
}

resource "aws_db_instance" "gymtracker" {
  identifier = "gymtracker-db"

  engine         = "postgres"
  engine_version = "16"

  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  storage_type          = "gp2"

  db_name  = "gymtracker"
  username = "gymuser"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.gymtracker.name
  vpc_security_group_ids = [aws_security_group.database.id]

  publicly_accessible = false
  skip_final_snapshot  = true

  tags = {
    Name = "gymtracker-database"
  }
}