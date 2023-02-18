locals {
       region = "us-east-1"
       vpc = "vpc-07e10c62a09e8cbcf"
       ssh-user = "ubuntu"
       ami = "ami-08c40ec9ead489470"
       instance-type = "t2.micro"
       subnet = "subnet-02b5a3aef483875c0" 
       publicip = true
       private-key-path = "/home/labsuser/prj2/prj2-key"
       keyname = "prj2-key-pair"
       sg-name = "wp-security-group"
}

provider "aws" {
  access_key = "ASIA4ZNDRFTFACBYCZH5"
  secret_key = "LGII+1+HUhZCEMMr4jZZedJPE8Fscv41IXPb0O1d" 
  token = "FwoGZXIvYXdzEM3//////////wEaDF5jqrVM2Br02v2GeiK6AaIeHqHYS3DzSl6fjrFK2obodTzhdFzvfhZLUPphwQ0tFMRd4Ch8VffNmHEuC0GjzWwHwf4r4fmJhnETMLsnnVqvUqBB+YaWc24LQDxMYyzP9XIRWX6Y5WEVqn8ml3nCQXru0IH6fCdbHOzTG/DZEF/HGD9iDViG97M1eMYh+v1IEo7CJyRDvMzSkWlCROKRnICHdm2IpwWI+vpBAkn12DkcZ97eig60qADvKmWTtb1ae9EEhd9vJmBORSi18bufBjItkcvCLMn9sck8G6gZy9/eOx4Y80+VJapYTjngT0fgA5xbfiV0hGUtwl1bmIMA"
  region = "us-east-1"
}

resource "aws_key_pair" "wp-key_pair" {
  key_name   = local.keyname
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC/QYuRngzifd0KkpNhTpvjMVZt/+JSXNT9ZOiUQD2b5mD9RUEDhEFM3Yl8J81KtzJvToZz4JLvI30P5tO3QSIwVbulHsQBAFnrvAlOKX0rj4QMo3vKIjVYqTQ8vifjlOGtwMpV2W9rSoIR0Zmkve/StaIpl1cGlp+2nAmh5hfZx2HFbMs0x1hrLoar6ddV6/c6WCYOiNyKJUF81+CecxJEOLz6hdqSG7QJiDI/vKZBgZj5KkoTQ4V12+J1bbwVls1BS9sK2Y00lkunabzUJd/E2JC6ikxRUHCijAnxaW07w1xE8t6DIjQWyiM6faq4K5a7dAOrtuFTsI+yASxnutQ3+/JkY6yfwEwy6F8i4PbexwDszHdtqNVAz8+YO+SUrxc6y/NSsILwGfdpGoYk/S2cbhdSIiv389Mfwey8NvkUMmi4eE4LKX/nbZmFlobk4YbwHIHpgeA/mo3RjgvJqHsDiJwJlIi9IsjAuDwR8GfPQDqLxGsdsSSu5LmzcjO02fk= labsuser@ip-172-31-49-58"
}

resource "aws_security_group" "wp-sg" {
     name = local.sg-name
     description = local.sg-name
     vpc_id = local.vpc

  // For HTTP access
  ingress {
       from_port = 80
       protocol = "tcp"
       to_port = 80
       cidr_blocks = ["0.0.0.0/0"]
  }

  // For HTTPS access
  ingress {
       from_port = 443
       protocol = "tcp"
       to_port = 443
       cidr_blocks = ["0.0.0.0/0"]
  }

  // For SSH connection
  ingress {
       from_port = 22
       protocol = "tcp"
       to_port = 22
       cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
       from_port       = 0
       to_port         = 0
       protocol        = "-1"
       cidr_blocks     = ["0.0.0.0/0"]
  }

  lifecycle {
        create_before_destroy = true
  }
}

resource "aws_instance" "wp-vm-instance" {
  ami = local.ami
  instance_type = local.instance-type
  subnet_id = local.subnet
  associate_public_ip_address = local.publicip
  key_name = local.keyname

  vpc_security_group_ids = [
    aws_security_group.wp-sg.id
  ]
  root_block_device {
      delete_on_termination = true
      volume_size = 50
      volume_type = "gp2"
  }

  tags = {
      Name ="WP-VM"
      Environment = "TEST"
      OS = "UBUNTU"
      Managed = "INFRA"
  }

  depends_on = [ aws_security_group.wp-sg ]

  connection {
    type = "ssh"
    host = self.public_ip
    user = local.ssh-user
    private_key = file(local.private-key-path)
    timeout = "4m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for SSH connection to be ready...'"
    ]
  }

  provisioner "local-exec" {
    # Export host public_ip as an Ansible inventory file
    command = "echo ${self.public_ip} > test-hosts"
  }

  provisioner "local-exec" {
    # Execute the Ansible playbook
    command = "ansible-playbook -i test-hosts --user ${local.ssh-user} --private-key ${local.private-key-path} playbook.yml"
  }
}
output "ec2instance" {
  value = aws_instance.wp-vm-instance.public_ip
}

