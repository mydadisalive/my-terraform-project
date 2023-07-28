provider "aws" {
  region = "us-east-1"  # Set your desired AWS region here
}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.default.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.default.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_security_group" "instance_sg" {
  name_prefix = "instance-sg-"
  vpc_id      = aws_vpc.default.id  # Associate the security group with the VPC

  # Allow SSH access from the public world
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP access from the public world
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.default.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create an AWS key pair using the public key
resource "aws_key_pair" "mykey" {
  key_name   = "mykey"
  public_key = file("mykey.pub")
}

resource "aws_instance" "test_instance" {
  ami           = "ami-05548f9cecf47b442"  # Set to the Amazon Linux 2 AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id  # Use the public subnet for testing instance
  associate_public_ip_address = true  # Request a public IP address for the instance

  user_data = <<-EOT
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y httpd
    echo "<html><body><h1>Hello, this is my test Apache web server on Amazon Linux 2!</h1></body></html>" | sudo tee /var/www/html/index.html
    sudo systemctl start httpd
  EOT

  tags = {
    Name = "test"
  }

  # Use the AWS key pair name
  key_name = aws_key_pair.mykey.key_name

  # Assign the security group to the instance
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
}

resource "aws_instance" "prod_instance" {
  ami           = "ami-05548f9cecf47b442"  # Set to the Amazon Linux 2 AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id  # Use the private subnet for production instance
  associate_public_ip_address = true  # Request a public IP address for the instance


  user_data = <<-EOT
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y httpd
    echo "<html><body><h1>Hello, this is my production Apache web server on Amazon Linux 2!</h1></body></html>" | sudo tee /var/www/html/index.html
    sudo systemctl start httpd
  EOT

  tags = {
    Name = "prod"
  }

  # Use the AWS key pair name
  key_name = aws_key_pair.mykey.key_name

  # Assign the security group to the instance
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
}

output "test_instance_public_ip" {
  value = aws_instance.test_instance.public_ip
}

output "test_instance_private_ip" {
  value = aws_instance.test_instance.private_ip
}

output "prod_instance_private_ip" {
  value = aws_instance.prod_instance.private_ip
}

output "prod_instance_public_ip" {
  value = aws_instance.prod_instance.public_ip
}

# Output the public IPs to a txt file
resource "local_file" "public_ips" {
  filename = "public_ips.txt"
  content  = <<EOT
Test Instance Public IP: ${aws_instance.test_instance.public_ip}
Prod Instance Private IP: ${aws_instance.prod_instance.private_ip}
Public Subnet ID: ${aws_subnet.public.id}
Private Subnet ID: ${aws_subnet.private.id}
EOT
}
