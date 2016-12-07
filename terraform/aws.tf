###
# Creates infrastructure in AWS for stealth app
# Author: Anton Lebiedyntsev
#
# Required vars:
#	var.access_key
#	var.secret_key
#	var.region
#	var.instance_type
#	var.instance_count
#	var.app_name
#	var.environment
#	var.my_name
#	var.control_cidr (for prod - all, dev predefined cidr)
###

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# Cereate VPC
resource "aws_vpc" "stealth" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags {
  	Name = "${var.my_name}_vpc"
  }
}

# Create Subnet in VPC
resource "aws_subnet" "stealth" {
  vpc_id = "${aws_vpc.stealth.id}"
  cidr_block = "10.0.0.0/24"
  availability_zone = "${var.region}${var.environment}"
  tags {
  	Name = "${var.my_name}_subnet"
  }
}

# AWS Networking
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.stealth.id}"
  tags {
  	Name = "${var.my_name}_gw"
  }
}

resource "aws_route_table" "stealth" {
    vpc_id = "${aws_vpc.stealth.id}"
    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.gw.id}"
    }
    tags {
  		Name = "${var.my_name}_rt"
  	}
}

resource "aws_route_table_association" "stealth" {
  subnet_id = "${aws_subnet.stealth.id}"
  route_table_id = "${aws_route_table.stealth.id}"
}

# Create Instances
resource "aws_instance" "stealth" {

  count = "${var.instance_count}"
  ami = "ami-1081b807"
  instance_type = "${var.instance_type}"

  subnet_id = "${aws_subnet.stealth.id}"
  availability_zone = "${var.region}${var.environment}"
  tags {
  	Name = "${var.app_name}-${count.index}"
  	ansibleFilter = "stealth${var.app_name}"
    ansibleNodeType = "${var.app_name}"
    ansibleNodeName = "${var.app_name}${count.index}"
  }
}

# Create ELB for instances
resource "aws_elb" "stealth" {
    name = "${var.my_name}_elb"
    instances = ["${aws_instance.stealth.*.id}"]
    subnets = ["${aws_subnet.stealth.id}"]
    cross_zone_load_balancing = false

    security_groups = ["${aws_security_group.stealth_elb.id}"]

    listener {
      lb_port = 443
      instance_port = 433
      lb_protocol = "TCP"
      instance_protocol = "TCP"
    }

    health_check {
      healthy_threshold = 2
      unhealthy_threshold = 2
      timeout = 15
      target = "HTTP:433/"
      interval = 30
    }
    tags {
  		Name = "${var.app_name}_elb"
  	}
}

# AWS Security
resource "aws_security_group" "stealth" {
  vpc_id = "${aws_vpc.stealth.id}"
  name = "${var.app_name}"

  # Allow all outbound
  egress {
    from_port = 0
    to_port = 0
    protocol = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all internal
  ingress {
    from_port = 0
    to_port = 0
    protocol = "all"
    self = true
  }

  # Allow all traffic 
  ingress {
    from_port = 0
    to_port = 0
    protocol = "all"
    security_groups = ["${aws_security_group.stealth_elb.id}"]
  }
}

resource "aws_security_group" "stealth_elb" {
  vpc_id = "${aws_vpc.stealth.id}"
  name = "${var.app_name}_elb"

  # Allow all outbound traffic
  egress {
    from_port = 0
    to_port = 0
    protocol = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }
    # Allow inbound traffic to the port 
  ingress {
    from_port = "https"
    to_port = "https"
    protocol = "TCP"
    cidr_blocks = ["${var.control_cidr}"]
  }
}


