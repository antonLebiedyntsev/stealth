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
#	var.zone
# var.ami_id
#	var.my_name
#	var.control_cidr (host allowed for SSH)
# var.web_cidr (for prod all, for dev predefined)
# var.key_name
# var.public_key
# var.environment
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
  availability_zone = "${var.region}${var.zone}"
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

resource "aws_key_pair" "stealth" {
  key_name = "${var.key_name}" 
  public_key = "${var.public_key}"
}

# Create Instances
resource "aws_instance" "stealth" {

  count = "${var.instance_count}"
  ami = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  associate_public_ip_address = true
  key_name = "${var.key_name}"
  subnet_id = "${aws_subnet.stealth.id}"
  availability_zone = "${var.region}${var.zone}"
  security_groups = ["${aws_security_group.stealth.id}"]
  tags {
    Name = "${var.app_name}-${var.environment}-${format("%02d", count.index+1)}"
    server_role = "${var.app_name}"
  }
}

# Create ELB for instances
resource "aws_elb" "stealth" {
    name = "${var.my_name}"
    instances = ["${aws_instance.stealth.*.id}"]
    subnets = ["${aws_subnet.stealth.id}"]

    cross_zone_load_balancing = false
    security_groups = ["${aws_security_group.stealth_elb.id}"]

    listener {
      lb_port = 80
      instance_port = 80
      lb_protocol = "TCP"
      instance_protocol = "TCP"
    }

    health_check {
      healthy_threshold = 2
      unhealthy_threshold = 2
      timeout = 15
      target = "HTTP:80/"
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
    protocol = "-1" #all
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Allow SSH for ansible
  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "TCP" # ALL
    cidr_blocks = ["${var.control_cidr}"]
  }

  # allows traffic from the SG itself
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1" #all
    self = true
  }

  # Allow all traffic In subbnet 
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1" #all
    cidr_blocks = ["10.0.0.0/24"]
  }
}

resource "aws_security_group" "stealth_elb" {
  vpc_id = "${aws_vpc.stealth.id}"
  name = "${var.app_name}_elb"

  # Allow all outbound traffic
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1" #all
    cidr_blocks = ["0.0.0.0/0"]
  }
    # Allow inbound traffic to the port 
  ingress {
    from_port = "80"
    to_port = "80"
    protocol = "TCP"
    cidr_blocks = ["${var.web_cidr}"]
  }

}



