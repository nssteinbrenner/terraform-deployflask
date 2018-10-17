provider "aws" {
  region = "us-west-2"
}

data "aws_availability_zones" "all" {}

output "elb_dns_name" {
  value = "${aws_elb.sparks-webserver.dns_name}"
}

resource "aws_security_group" "sparks-webserver" {
  name = "sparks-web-security"

  ingress {
    from_port = "443"
    to_port = "443"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_security_group" "sparks-loadbalancer" {
  name = "sparks-loadbalancer"
  
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "443"
    to_port = "443"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_launch_configuration" "sparks-webserver" {
  image_id = "${var.ami-id}"
  instance_type = "t2.micro"
  key_name = "Norns"
  security_groups = [ "${aws_security_group.sparks-webserver.id}" ]
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "sparks-webserver"  {
  launch_configuration = "${aws_launch_configuration.sparks-webserver.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  min_size = 2
  max_size = 10
  
  load_balancers = ["${aws_elb.sparks-webserver.name}"]
  health_check_type = "ELB"

  tag {
    key = "Name"
    value = "sparks-webserver-asg"
    propagate_at_launch = true
  }
}

resource "aws_elb" "sparks-webserver" {
  name = "sparks-webserver-elb"
  security_groups = ["${aws_security_group.sparks-loadbalancer.id}"]
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTPS:${443}/"
  }
  listener {
    lb_port = 443
    lb_protocol = "https"
    instance_port = "443"
    instance_protocol = "https"
    ssl_certificate_id = "arn:aws:acm:us-west-2:220507539732:certificate/f26cf614-3db4-45df-bb96-e8b59845f033"
  }
}
