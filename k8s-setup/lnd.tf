provider "aws" {
  region = "us-west-2"
}

variable "did" {
}

resource "aws_instance" "master" {
  ami                 = "ami-a9d09ed1"
  instance_type       = "t2.micro"
  key_name            = "devop-lnd"
  vpc_security_group_ids = [ "${aws_security_group.ClusterSecurityGroup.id}", "${aws_security_group.ExtSecurityGroup.id}"]
  source_dest_check   = false

  tags {
    Name = "master"
  }
}

resource "aws_instance" "node" {
  ami                 = "ami-a9d09ed1"
  instance_type       = "t2.micro"
  key_name            = "devop-lnd"
  vpc_security_group_ids = [ "${aws_security_group.ClusterSecurityGroup.id}", "${aws_security_group.ExtSecurityGroup.id}"]
  source_dest_check   = false

  tags {
    Name = "node"
  }
}

resource "aws_security_group" "ClusterSecurityGroup" {
  name = "${var.did}-ClusterSecurityGroup"
  description = "${var.did} cluster internal security group"

  ingress {
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    self       = true
  }
}

resource "aws_security_group" "ExtSecurityGroup" {
  description = "External front security group"
  ingress {
    from_port    = 22
    to_port      = 22
    protocol     = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]
  }
}

resource "aws_dynamodb_table" "k8s-join" {
  name              = "k8s-cluster-join"
  read_capacity     = 5
  write_capacity    = 5
  hash_key          = "did"

  attribute {
    name = "did"
    type = "S"
  }

}

resource "aws_iam_role_policy" "cluster_instance_policy" {
}

resource "aws_iam_role" "cluster_instance_role" {
  name = "
}
