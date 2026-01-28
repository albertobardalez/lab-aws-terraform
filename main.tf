# 1. Configuración del Motor de Terraform y Backend
terraform {
  backend "s3" {
    bucket         = "lab-devops-aba-2026"
    key            = "devops-lab/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
} # <--- El bloque 'terraform' se cierra aquí

# ---------------------------------------------------------
# 2. Configuración del Proveedor
# ---------------------------------------------------------
provider "aws" {
  region = "us-west-2"
}

# ---------------------------------------------------------
# 3. Datos (Data Sources) - Buscador de imagen Ubuntu
# ---------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ---------------------------------------------------------
# 4. Recursos de Red (VPC, Subnet, Internet Gateway)
# ---------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "VPC-Laboratorio-devops-2026" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"
  tags = { Name = "Subnet-Publica-Lab-DevOps" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "IGW-Laboratorio-DevOps" }
}

# ---------------------------------------------------------
# 5. Enrutamiento (Route Table y Asociación)
# ---------------------------------------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "Ruta-Publica-Lab" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ---------------------------------------------------------
# 6. Seguridad (Security Group para HTTP y SSH)
# ---------------------------------------------------------
resource "aws_security_group" "permitir_http" {
  name   = "permitir_http_ssh"
  vpc_id = aws_vpc.main.id

  # Puerto 80 para la Web
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Puerto 22 para SSH (Botón Conectar de AWS)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Salida libre a internet (Importante para apt-get)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------
# 7. El Servidor (Instancia EC2 Ubuntu)
# ---------------------------------------------------------
resource "aws_instance" "servidor_web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.permitir_http.id]

  # Garantiza que la red esté lista antes de prender la máquina
  depends_on = [aws_route_table_association.public_assoc]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2
              systemctl start apache2
              systemctl enable apache2
              echo "<h1>¡Laboratorio DevOps 2026: Despliegue Perfecto!</h1>" > /var/www/html/index.html
              EOF

  tags = { Name = "Servidor-Creado-Por-GitHub" }
}
#comentario