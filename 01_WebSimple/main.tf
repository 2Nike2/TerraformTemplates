
terraform  {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">=1.2.0"
}

provider "aws" {
  region = "ap-northeast-1"
}

# VPC
resource "aws_vpc" "web_simple_vpc" {
  cidr_block = "10.2.0.0/16"
  tags = {
    Name = "web_simple"
  }
}

# public subnet
resource "aws_subnet" "web_simple_public_subnet" {
  vpc_id = aws_vpc.web_simple_vpc.id
  availability_zone = "ap-northeast-1a"
  cidr_block = "10.2.1.0/24"
  tags = {
    Name = "web_simple_public_subnet"
  }
}

# internet gateway
resource "aws_internet_gateway" "web_simple_igw" {
  vpc_id = aws_vpc.web_simple_vpc.id
  tags = {
    Name = "web_simple_igw"
  }
}

# route table for public subnet
resource "aws_route_table" "web_simple_public_route_table" {
  vpc_id = aws_vpc.web_simple_vpc.id
  tags = {
    Name = "web_simple_public_route_table"
  }
}

# route for public subnet
resource "aws_route" "web_simple_public_route" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id = aws_route_table.web_simple_public_route_table.id
  gateway_id = aws_internet_gateway.web_simple_igw.id
}

# route table association for public subnet
resource "aws_route_table_association" "web_simple_public_route_table_association" {
  subnet_id = aws_subnet.web_simple_public_subnet.id
  route_table_id = aws_route_table.web_simple_public_route_table.id
}

# security group for web server
resource "aws_security_group" "web_simple_web_sg" {
  vpc_id = aws_vpc.web_simple_vpc.id
  tags = {
    Name = "web_simple_web_sg"
  }
}

# ingress rule for web server
resource "aws_vpc_security_group_ingress_rule" "web_simple_web_sg_ingress_rule" {
  security_group_id = aws_security_group.web_simple_web_sg.id
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

# egress rule for web server
resource "aws_vpc_security_group_egress_rule" "web_simple_web_sg_egress_rule" {
  security_group_id = aws_security_group.web_simple_web_sg.id
  from_port = 0
  to_port = 0
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}

# web server instance
resource "aws_instance" "web_simple_web_instance" {
  ami = "ami-0ab02459752898a60"
  instance_type = "t3.nano"
  user_data = base64encode(file("./user_data.sh"))
  subnet_id = aws_subnet.web_simple_public_subnet.id
  security_groups = [aws_security_group.web_simple_web_sg.id]
  tags = {
    Name = "web_simple_web_instance"
  }
}

# EIP
resource "aws_eip" "web_simple_eip" {
  domain = "vpc"
  tags ={
    Name = "web_simple_eip"
  }
}

# EIP association
resource "aws_eip_association" "web_simple_eip_association" {
  instance_id   = aws_instance.web_simple_web_instance.id
  allocation_id = aws_eip.web_simple_eip.id
}