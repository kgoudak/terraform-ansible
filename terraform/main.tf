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
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_cidr_newbits, 0)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_cidr_newbits, 1)
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-b"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_cidr_newbits, 2)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_cidr_newbits, 3)
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "private-subnet-b"
  }
}

# Elastic IPs
resource "aws_eip" "nat_a" {
  vpc = true
}

resource "aws_eip" "nat_b" {
  vpc = true
}

# NAT Gateways
resource "aws_nat_gateway" "ngw_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "nat-gw-a"
  }
}

resource "aws_nat_gateway" "ngw_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id

  tags = {
    Name = "nat-gw-b"
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

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw_a.id
  }

  tags = {
    Name = "private-rt-a"
  }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw_b.id
  }

  tags = {
    Name = "private-rt-b"
  }
}

# Subnet - Route Table associations
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
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
    description = "Allow Request to News API"
    from_port   = 8090
    to_port     = 8090
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

resource "aws_security_group" "alb" {
  name        = "alb sg"
  description = "Allow access to 8090"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow Request to Apache"
    from_port   = 8090
    to_port     = 8090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# EC2 instances
resource "aws_instance" "bastion" {
  ami                    = var.ec2_image_ids[var.region]
  instance_type          = var.ec2_instance_type
  key_name               = var.private_key_name
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.public.id]

  tags = {
    Name = "bastion"
  }
}

resource "aws_instance" "latest_news_api_a" {
  ami                         = var.ec2_image_ids[var.region]
  instance_type               = var.ec2_instance_type
  key_name                    = var.private_key_name
  subnet_id                   = aws_subnet.private_a.id
  vpc_security_group_ids      = [aws_security_group.private.id]
  associate_public_ip_address = false

  tags = {
    Name = "latest-news-api"
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
      bastion_private_key = file(var.private_key_file_path)
    }
  }

  provisioner "local-exec" {
    command = <<EOT
      ansible-playbook \
        -i '${self.private_ip},' \
        --ssh-common-args ' \
          -o ProxyCommand="ssh -A -W %h:%p -q ec2-user@${aws_instance.bastion.public_ip} \
                               -i ${var.private_key_file_path}"' \
        -u ec2-user \
        --private-key ${var.private_key_file_path} \
        ../ansible/backend.yml 
    EOT  
  }
}

resource "aws_instance" "latest_news_api_b" {
  ami                         = var.ec2_image_ids[var.region]
  instance_type               = var.ec2_instance_type
  key_name                    = var.private_key_name
  subnet_id                   = aws_subnet.private_b.id
  vpc_security_group_ids      = [aws_security_group.private.id]
  associate_public_ip_address = false

  tags = {
    Name = "latest-news-api"
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
      bastion_private_key = file(var.private_key_file_path)
    }
  }

  provisioner "local-exec" {
    command = <<EOT
      ansible-playbook \
        -i '${self.private_ip},' \
        --ssh-common-args ' \
          -o ProxyCommand="ssh -A -W %h:%p -q ec2-user@${aws_instance.bastion.public_ip} \
                               -i ${var.private_key_file_path}"' \
        -u ec2-user \
        --private-key ${var.private_key_file_path} \
        ../ansible/backend.yml 
    EOT  
  }
}

resource "aws_instance" "latest_news_website" {
  ami                    = var.ec2_image_ids[var.region]
  instance_type          = var.ec2_instance_type
  key_name               = var.private_key_name
  subnet_id              = aws_subnet.public_b.id
  vpc_security_group_ids = [aws_security_group.public.id]

  # Need to wait for latest-news-api LB to be created, as we need its DNS
  depends_on = [aws_lb.latest_news_api]

  tags = {
    Name = "latest-news-website"
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
      ansible-playbook \
        -i '${self.public_ip},' \
        -u ec2-user \
        --private-key ${var.private_key_file_path} \
        --extra-vars "host=${aws_lb.latest_news_api.dns_name}" \
        ../ansible/frontend.yml 
    EOT  
  }
}

# Application Load Balancers
resource "aws_lb" "latest_news_api" {
  name               = "latest-news-api-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "latest-news-api-lb"
  }
}

# Target Group
resource "aws_lb_target_group" "latest_news_api" {
  name     = "latest-news-api-lb-tg"
  port     = 8090
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    interval            = 10
    path                = "/actuator/health"
    port                = 8090
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }

  target_type = "instance"


  tags = {
    Name = "latest-news-api-lb-tg"
  }
}

# ALB Listeners
resource "aws_lb_listener" "latest_news_api" {
  load_balancer_arn = aws_lb.latest_news_api.arn
  port              = "8090"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.latest_news_api.arn
  }
}

# ALB Target Group Attachments
resource "aws_lb_target_group_attachment" "target_a" {
  target_group_arn = aws_lb_target_group.latest_news_api.arn
  target_id        = aws_instance.latest_news_api_a.id
  port             = 8090
}

resource "aws_lb_target_group_attachment" "target_b" {
  target_group_arn = aws_lb_target_group.latest_news_api.arn
  target_id        = aws_instance.latest_news_api_b.id
  port             = 8090
}
