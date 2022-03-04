output "DNS" {
  value = aws_instance.Web-JT.public_dns
}

output "InitialInstanceId" {
  value = aws_instance.Web-JT.id
}

output "AMI_ID" {
  value = aws_ami_from_instance.HTTPS_AMI.id
}

output "LoadBalancer" {
  value = aws_lb.HTTPS-LOAD-Front.dns_name
}