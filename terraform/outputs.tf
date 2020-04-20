output "bastion_public_address" {
  value       = aws_instance.bastion.public_ip
  description = "The public address of bastion host"
}

output "latest_news_api_lb_dns" {
  value       = aws_lb.latest_news_api.dns_name
  description = "The DNS name of the latest news api Load Balancer"
}

output "news_website_address" {
  value       = "http://${aws_instance.latest_news_website.public_dns}"
  description = "The public DNS of the news website"
}
