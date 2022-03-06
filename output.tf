
output "InitialInstanceId" {
  value = aws_instance.Web-JT.id
}

output "AMI_ID" {
  value = aws_ami_from_instance.HTTPS_AMI.id
}

output "LoadBalancer" {
  value = "https://${aws_lb.HTTPS-LOAD-Front.dns_name}"
}