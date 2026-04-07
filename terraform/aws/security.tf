# ─── AWS Security Hardening (Step 9) ─────────────────────────────────────────
# NACLs for spoke VPCs and additional security group rules

# NACL for spoke1 private subnet
resource "aws_network_acl" "spoke1_private" {
  vpc_id     = aws_vpc.spoke1.id
  subnet_ids = [aws_subnet.spoke1_private.id]

  # Inbound: allow ICMP from RFC1918
  ingress {
    rule_no    = 100
    protocol   = "icmp"
    action     = "allow"
    cidr_block = "10.0.0.0/8"
    from_port  = 0
    to_port    = 0
    icmp_type  = -1
    icmp_code  = -1
  }

  # Inbound: allow SSH from hub VPC only
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.hub_vpc_cidr
    from_port  = 22
    to_port    = 22
  }

  # Inbound: allow iperf3 from RFC1918
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "10.0.0.0/8"
    from_port  = 5201
    to_port    = 5201
  }

  # Inbound: allow ephemeral ports (return traffic)
  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Inbound: deny all else
  ingress {
    rule_no    = 32766
    protocol   = "-1"
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Outbound: allow all to RFC1918
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "10.0.0.0/8"
    from_port  = 0
    to_port    = 0
  }

  # Outbound: allow ephemeral ports to internet (for updates)
  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: deny all else
  egress {
    rule_no    = 32766
    protocol   = "-1"
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-${var.environment}-nacl-spoke1-private"
  })
}

# NACL for spoke2 private subnet (same rules, different subnet)
resource "aws_network_acl" "spoke2_private" {
  vpc_id     = aws_vpc.spoke2.id
  subnet_ids = [aws_subnet.spoke2_private.id]

  ingress {
    rule_no    = 100
    protocol   = "icmp"
    action     = "allow"
    cidr_block = "10.0.0.0/8"
    from_port  = 0
    to_port    = 0
    icmp_type  = -1
    icmp_code  = -1
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.hub_vpc_cidr
    from_port  = 22
    to_port    = 22
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "10.0.0.0/8"
    from_port  = 5201
    to_port    = 5201
  }

  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    rule_no    = 32766
    protocol   = "-1"
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "10.0.0.0/8"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 32766
    protocol   = "-1"
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-${var.environment}-nacl-spoke2-private"
  })
}
