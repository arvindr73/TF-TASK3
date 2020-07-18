# Specify the provider and access details

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "ap-south-1"
}

variable "vpc_cidr" {
    description = "CIDR for the whole VPC"
    default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
    description = "CIDR for the Public Subnet"
    default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
    description = "CIDR for the Private Subnet"
    default = "10.0.2.0/24"
}

provider "aws" {
  region = "${var.aws_region}"
}

// create a key-pair

resource "tls_private_key" "key-pair" {
	algorithm = "RSA"
	rsa_bits = 4096
}


resource "local_file" "private-key" {
    content = tls_private_key.key-pair.private_key_pem
    filename = 	"vpckey.pem"
    file_permission = "0400"
}

resource "aws_key_pair" "deployer" {
  key_name   = "vpckey"
  public_key = tls_private_key.key-pair.public_key_openssh
}

// Create a VPC to launch our instances into

resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}


// Create a Public subnet to launch our instances into

resource "aws_subnet" "public" {
  vpc_id = "${aws_vpc.my-vpc.id}"
  cidr_block = "${var.public_subnet_cidr}"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"
}

// Create a Private subnet to launch our instances into

resource "aws_subnet" "private" {
  vpc_id = "${aws_vpc.my-vpc.id}"
  cidr_block = "${var.private_subnet_cidr}"
  map_public_ip_on_launch = false
  availability_zone = "ap-south-1b"
 }


// Create an internet gateway to give our subnet access to the outside world

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.my-vpc.id}"
}

// Create a Route Table 

resource "aws_route_table" "myrt" {
    vpc_id = "${aws_vpc.my-vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.default.id}"
    }
}

// Associate Route Table with Public subnet

resource "aws_route_table_association" "rt-public" {
    subnet_id = "${aws_subnet.public.id}"
    route_table_id = "${aws_route_table.myrt.id}"
}


// create security group for WordPress

resource "aws_security_group" "wp" { 

  name        = "mysg-tf2" 
  description = "Allow traffic from port 80 & 22" 
  vpc_id      = "${aws_vpc.my-vpc.id}"
 
 ingress { 
     description = "ALL ICMP-IPv4" 
     from_port   = -1
     to_port     = -1 
     protocol    = "icmp" 
     cidr_blocks = ["0.0.0.0/0"] 
   } 
 
   ingress { 
     description = "HTTP" 
     from_port   = 80 
     to_port     = 80 
     protocol    = "tcp" 
     cidr_blocks = ["0.0.0.0/0"] 
   } 
   
  ingress { 
     description = "SSH" 
     from_port   = 22 
     to_port     = 22 
     protocol    = "tcp" 
     cidr_blocks = ["0.0.0.0/0"] 
   } 
  
   egress { 
     from_port   = 0 
     to_port     = 0 
     protocol    = "-1" 
     cidr_blocks = ["0.0.0.0/0"] 
 }
 
 egress { 
     from_port = 3306
     to_port = 3306
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
}
 tags = { 
    Name = "mysecgrp-sg2" 
  } 
} 

// create security group for MySQL Database

resource "aws_security_group" "db" {
    name = "vpc_db"
    description = "Allow incoming database connections."
    vpc_id = "${aws_vpc.my-vpc.id}"

     ingress { 
           from_port = 3306
           to_port = 3306
           protocol = "tcp"
           security_groups = ["${aws_security_group.wp.id}"]
       }
   
     egress {
         from_port = 0
         to_port = 0  
         protocol = "-1"
         cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "DBServerSG"
    }
}


// Launch MySQL instance in Private Subnet with a key pair as well as DB security group

resource "aws_instance" "MySQL" {
   ami = "ami-76166b19"
   instance_type = "t2.micro"
   key_name = "vpckey"
   subnet_id = "${aws_subnet.private.id}"
  vpc_security_group_ids = ["${aws_security_group.db.id}"]
    tags = {
        Name = "WordPress DB Instance"
    }
}

// launch Wordpress instance in Public Subnet having public IP &  with the key-pair as well as Security group created above


resource "aws_instance" "wp" {
//ami = "ami-0979674e4a8c6ea0c"
//ami = "ami-7e257211"
 ami= "ami-ff82f990"
instance_type = "t2.micro"
key_name = "vpckey"
security_groups = ["${aws_security_group.wp.id }"] 
subnet_id = "${aws_subnet.public.id}"
availability_zone = "ap-south-1a"
tags = {
  Name = "Wordpress"
  } 
}



output "ip_address" {
    value = "${aws_instance.wp.public_ip}"
}
 
output "Wordpress_Instance_Id" {
    value = "${aws_instance.wp.id}"
}