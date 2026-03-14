terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ──────────────────────────────────────────────
# AMI
# ──────────────────────────────────────────────
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ──────────────────────────────────────────────
# VPCs
# ──────────────────────────────────────────────
resource "aws_vpc" "hub" {
  cidr_block           = var.hub_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.project_name}-hub-vpc" })
}

resource "aws_vpc" "spoke1" {
  cidr_block           = var.spoke1_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.project_name}-spoke1-vpc" })
}

resource "aws_vpc" "spoke2" {
  cidr_block           = var.spoke2_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.project_name}-spoke2-vpc" })
}

# ──────────────────────────────────────────────
# Internet Gateway (hub only)
# ──────────────────────────────────────────────
resource "aws_internet_gateway" "hub" {
  vpc_id = aws_vpc.hub.id
  tags   = merge(local.tags, { Name = "${var.project_name}-hub-igw" })
}

# ──────────────────────────────────────────────
# Subnets
# ──────────────────────────────────────────────
resource "aws_subnet" "hub_public" {
  vpc_id                  = aws_vpc.hub.id
  cidr_block              = var.hub_public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${var.project_name}-hub-public" })
}

resource "aws_subnet" "hub_private" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = var.hub_private_subnet_cidr
  availability_zone = "${var.aws_region}b"
  tags              = merge(local.tags, { Name = "${var.project_name}-hub-private" })
}

resource "aws_subnet" "spoke1_public" {
  vpc_id                  = aws_vpc.spoke1.id
  cidr_block              = var.spoke1_public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${var.project_name}-spoke1-public" })
}

resource "aws_subnet" "spoke1_private" {
  vpc_id            = aws_vpc.spoke1.id
  cidr_block        = var.spoke1_private_subnet_cidr
  availability_zone = "${var.aws_region}b"
  tags              = merge(local.tags, { Name = "${var.project_name}-spoke1-private" })
}

resource "aws_subnet" "spoke2_public" {
  vpc_id                  = aws_vpc.spoke2.id
  cidr_block              = var.spoke2_public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${var.project_name}-spoke2-public" })
}

resource "aws_subnet" "spoke2_private" {
  vpc_id            = aws_vpc.spoke2.id
  cidr_block        = var.spoke2_private_subnet_cidr
  availability_zone = "${var.aws_region}b"
  tags              = merge(local.tags, { Name = "${var.project_name}-spoke2-private" })
}

# ──────────────────────────────────────────────
# Transit Gateway
# ──────────────────────────────────────────────
resource "aws_ec2_transit_gateway" "main" {
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  tags                            = merge(local.tags, { Name = "${var.project_name}-tgw" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.hub.id
  subnet_ids         = [aws_subnet.hub_private.id]
  tags               = merge(local.tags, { Name = "${var.project_name}-tgw-attach-hub" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke1" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.spoke1.id
  subnet_ids         = [aws_subnet.spoke1_private.id]
  tags               = merge(local.tags, { Name = "${var.project_name}-tgw-attach-spoke1" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke2" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.spoke2.id
  subnet_ids         = [aws_subnet.spoke2_private.id]
  tags               = merge(local.tags, { Name = "${var.project_name}-tgw-attach-spoke2" })
}

# TGW Route Table
resource "aws_ec2_transit_gateway_route_table" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags               = merge(local.tags, { Name = "${var.project_name}-tgw-rt" })
}

# TGW Route Table Associations
resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

# TGW Route Table Propagations
resource "aws_ec2_transit_gateway_route_table_propagation" "hub" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

# ──────────────────────────────────────────────
# Route Tables
# ──────────────────────────────────────────────

# Hub public route table
resource "aws_route_table" "hub_public" {
  vpc_id = aws_vpc.hub.id
  tags   = merge(local.tags, { Name = "${var.project_name}-hub-public-rt" })

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hub.id
  }
}

resource "aws_route_table_association" "hub_public" {
  subnet_id      = aws_subnet.hub_public.id
  route_table_id = aws_route_table.hub_public.id
}

# Hub private route table
resource "aws_route_table" "hub_private" {
  vpc_id = aws_vpc.hub.id
  tags   = merge(local.tags, { Name = "${var.project_name}-hub-private-rt" })

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }
}

resource "aws_route_table_association" "hub_private" {
  subnet_id      = aws_subnet.hub_private.id
  route_table_id = aws_route_table.hub_private.id
}

# Spoke1 route table
resource "aws_route_table" "spoke1" {
  vpc_id = aws_vpc.spoke1.id
  tags   = merge(local.tags, { Name = "${var.project_name}-spoke1-rt" })

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }
}

resource "aws_route_table_association" "spoke1_public" {
  subnet_id      = aws_subnet.spoke1_public.id
  route_table_id = aws_route_table.spoke1.id
}

resource "aws_route_table_association" "spoke1_private" {
  subnet_id      = aws_subnet.spoke1_private.id
  route_table_id = aws_route_table.spoke1.id
}

# Spoke2 route table
resource "aws_route_table" "spoke2" {
  vpc_id = aws_vpc.spoke2.id
  tags   = merge(local.tags, { Name = "${var.project_name}-spoke2-rt" })

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }
}

resource "aws_route_table_association" "spoke2_public" {
  subnet_id      = aws_subnet.spoke2_public.id
  route_table_id = aws_route_table.spoke2.id
}

resource "aws_route_table_association" "spoke2_private" {
  subnet_id      = aws_subnet.spoke2_private.id
  route_table_id = aws_route_table.spoke2.id
}

# ──────────────────────────────────────────────
# Security Groups
# ──────────────────────────────────────────────

# Hub security group
resource "aws_security_group" "hub" {
  name        = "${var.project_name}-hub-sg"
  description = "Hub VPC security group"
  vpc_id      = aws_vpc.hub.id
  tags        = merge(local.tags, { Name = "${var.project_name}-hub-sg" })

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP from RFC1918 10/8"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Spoke security group (shared template; one per spoke VPC)
resource "aws_security_group" "spoke1" {
  name        = "${var.project_name}-spoke1-sg"
  description = "Spoke1 VPC security group"
  vpc_id      = aws_vpc.spoke1.id
  tags        = merge(local.tags, { Name = "${var.project_name}-spoke1-sg" })

  ingress {
    description = "SSH from hub VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.hub_vpc_cidr]
  }

  ingress {
    description = "ICMP from RFC1918 10/8"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    description = "iperf3 from RFC1918 10/8"
    from_port   = 5201
    to_port     = 5201
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "spoke2" {
  name        = "${var.project_name}-spoke2-sg"
  description = "Spoke2 VPC security group"
  vpc_id      = aws_vpc.spoke2.id
  tags        = merge(local.tags, { Name = "${var.project_name}-spoke2-sg" })

  ingress {
    description = "SSH from hub VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.hub_vpc_cidr]
  }

  ingress {
    description = "ICMP from RFC1918 10/8"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    description = "iperf3 from RFC1918 10/8"
    from_port   = 5201
    to_port     = 5201
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ──────────────────────────────────────────────
# CloudWatch Log Group & IAM for VPC Flow Logs
# ──────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 30
  tags              = local.tags
}

data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name               = "vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "vpc_flow_logs_cloudwatch" {
  role       = aws_iam_role.vpc_flow_logs.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# ──────────────────────────────────────────────
# VPC Flow Logs
# ──────────────────────────────────────────────
resource "aws_flow_log" "hub" {
  vpc_id               = aws_vpc.hub.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  tags                 = merge(local.tags, { Name = "${var.project_name}-hub-flow-log" })
}

resource "aws_flow_log" "spoke1" {
  vpc_id               = aws_vpc.spoke1.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  tags                 = merge(local.tags, { Name = "${var.project_name}-spoke1-flow-log" })
}

resource "aws_flow_log" "spoke2" {
  vpc_id               = aws_vpc.spoke2.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  tags                 = merge(local.tags, { Name = "${var.project_name}-spoke2-flow-log" })
}

# ──────────────────────────────────────────────
# EC2 Instances
# ──────────────────────────────────────────────
locals {
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y iperf3
  EOF
}

resource "aws_instance" "hub_test" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.hub_private.id
  vpc_security_group_ids = [aws_security_group.hub.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null
  user_data              = local.user_data

  tags = merge(local.tags, { Name = "${var.project_name}-hub-test" })
}

resource "aws_instance" "spoke1_test" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.spoke1_private.id
  vpc_security_group_ids = [aws_security_group.spoke1.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null
  user_data              = local.user_data

  tags = merge(local.tags, { Name = "${var.project_name}-spoke1-test" })
}

resource "aws_instance" "spoke2_test" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.spoke2_private.id
  vpc_security_group_ids = [aws_security_group.spoke2.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null
  user_data              = local.user_data

  tags = merge(local.tags, { Name = "${var.project_name}-spoke2-test" })
}
