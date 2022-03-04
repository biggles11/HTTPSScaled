resource "aws_vpc" "HTTP-VPC" {
   cidr_block = "10.10.0.0/16"
}

resource "aws_subnet" "defaulta" {
  vpc_id                  = "${aws_vpc.HTTP-VPC.id}"
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${var.aws_region}a"
}

resource "aws_subnet" "defaultb" {
  vpc_id                  = "${aws_vpc.HTTP-VPC.id}"
  cidr_block              = "10.10.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${var.aws_region}b"
}

resource "aws_subnet" "defaultc" {
  vpc_id                  = "${aws_vpc.HTTP-VPC.id}"
  cidr_block              = "10.10.3.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${var.aws_region}c"
}
resource "aws_internet_gateway" "https_gw" {
  vpc_id = aws_vpc.HTTP-VPC.id
  tags = {
    Name = "https default internet gw"
  }
}
resource "aws_route_table" "HTTPSTable" {
  vpc_id = aws_vpc.HTTP-VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.https_gw.id
  }
  tags = {
    Name = "HTTPSRoutingTable"
  }
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.defaulta.id
  route_table_id = aws_route_table.HTTPSTable.id
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.defaultb.id
  route_table_id = aws_route_table.HTTPSTable.id
}
resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.defaultc.id
  route_table_id = aws_route_table.HTTPSTable.id
}

#Create security group to allow ssh and HTTPSWebServer
resource "aws_security_group" "HTTPS-Web-Server" {
  name = "HTTPSWeb-HTTPS"
  description = "Allow ssh and https traffic"
  vpc_id      = aws_vpc.HTTP-VPC.id

  ingress {
           from_port = 22
           to_port = 22
           protocol = "tcp"
           cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
           from_port = 443
           to_port = 443
           protocol = "tcp"
           cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "HTTPS-LOAD-Front" {
  name               = "HTTPS-LOAD-Front"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${aws_subnet.defaulta.id}","${aws_subnet.defaultb.id}","${aws_subnet.defaultc.id}"]
}
resource "aws_lb_target_group" "https-targets" {
  name     = "https-targets"
  port     = 443
  protocol = "TCP"
  vpc_id   = "${aws_vpc.HTTP-VPC.id}"
}

resource "aws_lb_listener" "HTTPSServer" {
  load_balancer_arn = aws_lb.HTTPS-LOAD-Front.arn
  port              = "443"
  protocol          = "TCP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https-targets.arn
  }
}

resource "aws_instance" "Web-JT" {
  ami           = "ami-060c4f2d72966500a"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.HTTPS-Web-Server.id}"]
  subnet_id = aws_subnet.defaulta.id
  #security_groups = ["${aws_security_group.HTTPS-Web-Server.id}"]
  user_data = <<EOF
              #!/bin/bash
              yum update -y
              yum install ec2-instance-connect
              yum install -y httpd
              yum install -y mod_ssl
              yum install -y php
              sed -i 's/Listen 80//g' /etc/httpd/conf/httpd.conf
              service httpd start
              chkconfig httpd on
              cat > /var/www/html/index.php <<'endmsg'
              <!DOCTYPE html>
<html><meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<title>What's my IP</title>
	<body>
		<div id="tools" class="tools">
			<p>Your IP is:</p>
		</div>
		<div id="ip-lookup" class="tools">
			<?php if ($_SERVER["HTTP_X_FORWARDED_FOR"] != "") {
				$IP = $_SERVER["HTTP_X_FORWARDED_FOR"];
				$proxy = $_SERVER["REMOTE_ADDR"];
				$host = @gethostbyaddr($_SERVER["HTTP_X_FORWARDED_FOR"]);
			} else {
				$IP = $_SERVER["REMOTE_ADDR"];
				$host = @gethostbyaddr($_SERVER["REMOTE_ADDR"]);
			} ?>
			<h1><?php echo $IP; ?></h1>
		</div>
    		<div id="tools" class="tools">
			<p>The Server hosting this page is:</p>
		</div>
		<div id="ip-lookup" class="tools">
			<?php 
      $IPHOST = @gethostbyname(getHostName());
      ?>
			<h1><?php echo $IPHOST; ?></h1>
		</div>
		<div id="more" class="tools">
			<p><a id="more-link" title="More information" href="javascript:toggle();">More info</a></p>
		</div>
		<div id="more-info" class="tools">
			<ul>
			<?php
				echo '<li><strong>Remote Port:</strong> <span>'.$_SERVER["REMOTE_PORT"].'</span></li>';
				echo '<li><strong>Request Method:</strong> <span>'.$_SERVER["REQUEST_METHOD"].'</span></li>';
				echo '<li><strong>Server Protocol:</strong> <span>'.$_SERVER["SERVER_PROTOCOL"].'</span></li>';
				echo '<li><strong>Server Host:</strong> <span>'.$host.'</span></li>';
				echo '<li><strong>User Agent:</strong> <span>'.$_SERVER["HTTP_USER_AGENT"].'</span></li>';
				if ($proxy) echo '<li><strong>Proxy: <span>'.($proxy) ? $proxy : ''.'</span></li>';

				$time_start = microtime(true);
				usleep(100);
				$time_end = microtime(true);
				$time = $time_end - $time_start;
			?>
			</ul>
			<p><small>It took <?php echo $time; ?> seconds to share this info.</small></p>
		</div>
	</body>
</html>
endmsg
              EOF
  associate_public_ip_address = true
  tags = {
    Name = "HTTPSWebServer"
  }
}

resource "aws_ami_from_instance" "HTTPS_AMI" {
  name = "HTTPS_AMI"
  source_instance_id = aws_instance.Web-JT.id
}

resource "aws_launch_template" "HTTPS_Instance_Launch" {
  name_prefix = "HTTPS_Instance_Launch"
  image_id = "${aws_ami_from_instance.HTTPS_AMI.id}"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.HTTPS-Web-Server.id}"]
}

resource "aws_autoscaling_group" "HTTPS_Scaling_Group" {
  #availability_zones = ["${var.aws_region}a","${var.aws_region}b","${var.aws_region}c"]
  desired_capacity   = 3
  max_size           = 3
  min_size           = 3
  target_group_arns  = ["${aws_lb_target_group.https-targets.arn}"]
  vpc_zone_identifier = ["${aws_subnet.defaulta.id}","${aws_subnet.defaultb.id}","${aws_subnet.defaultc.id}"]

  launch_template {
    id      = "${aws_launch_template.HTTPS_Instance_Launch.id}"
    version = "${aws_launch_template.HTTPS_Instance_Launch.latest_version}"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      instance_warmup = 200
      min_healthy_percentage = 90
    }
  }
}
