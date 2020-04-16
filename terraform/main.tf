# Set cloud provider and default region
provider "aws" {
  region = var.region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-vpc-igw"
  }
}

# Subnets
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_cidr_newbits, 0)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_cidr_newbits, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "private-subnet"
  }
}

# Elastic IPs
resource "aws_eip" "nat" {
  vpc = true
}

# NAT Gateways
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "nat-gw"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "private-rt"
  }
}

# Subnet - Route Table associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security Groups
resource "aws_security_group" "public" {
  name        = "public sg"
  description = "Allow Ping, SSH and HTTP access for resources in public subnets"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow ping"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["${var.ssh_location}/32"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.ssh_location}/32"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.ssh_location}/32"]
  }

  ingress {
    description = "Allow Request to Apache"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${var.ssh_location}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-sg"
  }
}

resource "aws_security_group" "private" {
  name        = "private sg"
  description = "Allow Ping, SSH and HTTP access for resources in private subnets"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow ping"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-sg"
  }
}

# EC2 instances
resource "aws_instance" "bastion" {
  ami                    = var.ec2_image_ids[var.region]
  instance_type          = var.ec2_instance_type
  key_name               = var.private_key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public.id]

  tags = {
    Name = "bastion"
  }
}

resource "aws_instance" "news_api" {
  ami                         = var.ec2_image_ids[var.region]
  instance_type               = var.ec2_instance_type
  key_name                    = var.private_key_name
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.private.id]
  associate_public_ip_address = false

  tags = {
    Name = "news-api"
  }

  depends_on = [aws_instance.bastion]

  # We run this to make sure server is initialized before we run the "local exec"
  provisioner "remote-exec" {
    inline = ["echo 'Waiting for server to be initialized...'"]

    connection {
      type        = "ssh"
      agent       = false
      host        = self.private_ip
      user        = "ec2-user"
      private_key = file(var.private_key_file_path)

      bastion_host        = aws_instance.bastion.public_ip
      bastion_private_key = file("~/.ssh/aws/kostas-kp.pem")
    }
  }

  provisioner "local-exec" {
    command = <<EOT
      ansible-playbook -i '${self.private_ip},' \
      --ssh-common-args '-o ProxyCommand="ssh -W %h:%p -q ec2-user@${aws_instance.bastion.public_ip}" ' \
      -u ec2-user \
      --private-key ${var.private_key_file_path} \
      ../ansible/backend.yml 
    EOT  
  }
}

resource "aws_instance" "news_website" {
  ami                    = var.ec2_image_ids[var.region]
  instance_type          = var.ec2_instance_type
  key_name               = var.private_key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public.id]

  depends_on = [aws_instance.news_api]

  tags = {
    Name = "news-website"
  }

  # We run this to make sure server is initialized before we run the "local exec"
  provisioner "remote-exec" {
    inline = ["echo 'Waiting for server to be initialized...'"]

    connection {
      type        = "ssh"
      agent       = false
      host        = self.public_ip
      user        = "ec2-user"
      private_key = file(var.private_key_file_path)
    }
  }

  provisioner "local-exec" {
    command = <<EOT
      ansible-playbook  -i '${self.public_ip},' \
                        -u ec2-user \
                        --private-key ${var.private_key_file_path} \
                        --extra-vars "host=${aws_instance.news_api.private_ip}" \
                        ../ansible/frontend.yml 
    EOT  
  }
}
