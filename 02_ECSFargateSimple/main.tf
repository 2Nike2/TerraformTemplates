terraform {
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
resource "aws_vpc" "ecs_simple_vpc" {
  cidr_block = "10.3.0.0/16"
  tags = {
    Name = "ecs_simple"
  }
}

# public subnet
resource "aws_subnet" "ecs_simple_public_subnet" {
  vpc_id = aws_vpc.ecs_simple_vpc.id
  availability_zone = "ap-northeast-1a"
  cidr_block = "10.3.1.0/24"
  tags = {
    Name = "ecs_simple_public_subnet"
  }
}

# internet gateway
resource "aws_internet_gateway" "ecs_simple_igw" {
  vpc_id = aws_vpc.ecs_simple_vpc.id
  tags = {
    Name = "ecs_simple_igw"
  }
}

# route table for public subnet
resource "aws_route_table" "ecs_simple_public_route_table" {
  vpc_id = aws_vpc.ecs_simple_vpc.id
  tags = {
    Name = "ecs_simple_public_route_table"
  }
}

# route for public subnet
resource "aws_route" "ecs_simple_public_route" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id = aws_route_table.ecs_simple_public_route_table.id
  gateway_id = aws_internet_gateway.ecs_simple_igw.id
}

# route table association for public subnet
resource "aws_route_table_association" "ecs_simple_public_route_table_association" {
  subnet_id = aws_subnet.ecs_simple_public_subnet.id
  route_table_id = aws_route_table.ecs_simple_public_route_table.id
}

# IAM role policy for ECS
data "aws_iam_policy_document" "ecs_simple_ecs_role_policy" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# IAM role for ECS
resource "aws_iam_role" "ecs_simple_ecs_role" {
  name = "ecs_simple_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_simple_ecs_role_policy.json
}

# IAM role policy for EC2 instance
data "aws_iam_policy_document" "ecs_simple_ec2_role_policy" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# IAM role for EC2 instance
resource "aws_iam_role" "ecs_simple_ec2_role" {
  name = "ecs_simple_ec2_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_simple_ec2_role_policy.json
}

# ECS cluster
resource "aws_ecs_cluster" "ecs_simple_cluster" {
  name = "ecs_simple_cluster"
}

# Task definition
resource "aws_ecs_task_definition" "ecs_simple_task_definition" {
  family = "ecs_simple_task"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "256"
  memory = "512"
  execution_role_arn = aws_iam_role.ecs_simple_ecs_role.arn
  container_definitions = jsonencode([
    {
      name = "ecs_simple_container"
      image = "nginx:latest"
      cpu = 256
      memory = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort = 80
          protocol = "tcp"
        }
      ]
    }
  ])
}

# security group for instance
resource "aws_security_group" "ecs_simple_instance_sg" {
  vpc_id = aws_vpc.ecs_simple_vpc.id
  tags = {
    Name = "ecs_simple_instance_sg"
  }
}

# ingress rule
resource "aws_vpc_security_group_ingress_rule" "ecs_simple_instance_sg_ingress_rule" {
  security_group_id = aws_security_group.ecs_simple_instance_sg.id
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

# egress rule 
resource "aws_vpc_security_group_egress_rule" "ecs_simple_instance_sg_egress_rule" {
  security_group_id = aws_security_group.ecs_simple_instance_sg.id
  from_port = 0
  to_port = 0
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_ecs_service" "ecs_simple_service" {
  name = "ecs_simple_service"
  cluster = aws_ecs_cluster.ecs_simple_cluster.id
  task_definition = aws_ecs_task_definition.ecs_simple_task_definition.arn
  launch_type = "FARGATE"
  desired_count = 2
  network_configuration {
    subnets = [aws_subnet.ecs_simple_public_subnet.id]
    security_groups = [aws_security_group.ecs_simple_instance_sg.id]
    assign_public_ip = true
  }
}

# 参考
# https://amegaeru.hatenablog.jp/entry/2023/08/20/000000