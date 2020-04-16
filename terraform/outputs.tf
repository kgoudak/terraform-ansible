output "bastion_public_address" {
  value       = aws_instance.bastion.public_ip
  description = "The public address of bastion host"
}

output "news_website_address" {
  value       = "http://${aws_instance.news_website.public_ip}"
  description = "The public address of the news website"
}
