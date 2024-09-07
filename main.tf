terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = "true"

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  owners = ["146379056159"]
}

resource "aws_vpc" "test-vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "test-vpc"
  }
}

resource "aws_internet_gateway" "test_igw" {
  vpc_id = aws_vpc.test-vpc.id
  tags = {
    Name = "test_igw"
  }
}

resource "aws_subnet" "test_public_subnet" {
  count             = var.subnet_count.public
  vpc_id            = aws_vpc.test-vpc.id
  cidr_block        = var.public_subnet_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "test_public_subnet_${count.index}"
  }
}

resource "aws_subnet" "test_private_subnet" {
  count             = var.subnet_count.private
  vpc_id            = aws_vpc.test-vpc.id
  cidr_block        = var.private_subnet_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "test_private_subnet_${count.index}"
  }
}
resource "aws_route_table" "test_public_rt" {
  vpc_id = aws_vpc.test-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test_igw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = var.subnet_count.public
  route_table_id = aws_route_table.test_public_rt.id
  subnet_id      = 	aws_subnet.test_public_subnet[count.index].id
}

resource "aws_route_table" "test_private_rt" {
  vpc_id = aws_vpc.test-vpc.id
}

resource "aws_route_table_association" "private" {
  count          = var.subnet_count.private
  route_table_id = aws_route_table.test_private_rt.id
  subnet_id      = aws_subnet.test_private_subnet[count.index].id
}

resource "aws_security_group" "test_web_sg" {
  name        = "test_web_sg"
  description = "Security group for test web servers"
  vpc_id      = aws_vpc.test-vpc.id
  ingress {
    description = "Allow all traffic through HTTP"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH from my computer"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "test_web_sg"
  }
}

resource "aws_security_group" "test_db_sg" {
  name        = "test_db_sg"
  description = "Security group for test databases"
  vpc_id      = aws_vpc.test-vpc.id
  ingress {
    description     = "Allow MySQL traffic from only the web sg"
    from_port       = "3306"
    to_port         = "3306"
    protocol        = "tcp"
    security_groups = [aws_security_group.test_web_sg.id]
  }
  tags = {
    Name = "test_db_sg"
  }
}
resource "aws_db_subnet_group" "test_db_subnet_group" {
  name        = "test_db_subnet_group"
  description = "DB subnet group for test"
  subnet_ids  = [for subnet in aws_subnet.test_private_subnet : subnet.id]
}

resource "aws_db_instance" "test_database" {
  allocated_storage      = var.settings.database.allocated_storage
  engine                 = var.settings.database.engine
  instance_class         = var.settings.database.instance_class
  db_name                = var.settings.database.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.test_db_subnet_group.id
  vpc_security_group_ids = [aws_security_group.test_db_sg.id]
  skip_final_snapshot    = var.settings.database.skip_final_snapshot
}

resource "aws_key_pair" "test_kp" {
  key_name   = "test_kp"
  public_key = file("test_kp.pub")
}

resource "aws_efs_file_system" "test_efs" {
  creation_token = "test-efs"
}

resource "aws_efs_mount_target" "test_efs_mount_target" {
  file_system_id = aws_efs_file_system.test_efs.id
  count          = length(aws_subnet.test_public_subnet)
  subnet_id      = aws_subnet.test_public_subnet[count.index].id
}

resource "aws_instance" "test_web" {
  count                  = var.settings.web_app.count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.settings.web_app.instance_type
  subnet_id              = aws_subnet.test_public_subnet[count.index].id
  key_name               = aws_key_pair.test_kp.key_name
  vpc_security_group_ids = [aws_security_group.test_web_sg.id]
  user_data = file("user_data_script.sh")

  tags = {
    Name = "test_web_${count.index}"
  }
}

resource "aws_eip" "test_web_eip" {
  count    = var.settings.web_app.count
  instance = aws_instance.test_web[count.index].id
  vpc      = true
  tags = {
    Name = "test_web_eip_${count.index}"
  }
}

resource "aws_lb" "test_lb" {
  name               = "test-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.test_web_sg.id]
  subnets            = aws_subnet.test_public_subnet[*].id

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "test_target_group" {
  name     = "test-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.test-vpc.id
}

resource "aws_lb_listener" "test_lb_listener" {
  load_balancer_arn = aws_lb.test_lb.arn
  port              = 80
  protocol          = "HTTP"

 default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      message_body = "Hello, world!"
    }
  }
}

resource "aws_lb_target_group_attachment" "test_lb_attachment" {
  target_group_arn = aws_lb_target_group.test_target_group.arn
  count            = length(aws_instance.test_web)
  target_id        = aws_instance.test_web[count.index].id
  port             = 80
}

resource "aws_cloudwatch_metric_alarm" "requests_alarm" {
  alarm_name          = "HighRequestCountAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1000"
  alarm_description  = "Alarm when the total number of requests exceeds 1000"
}
