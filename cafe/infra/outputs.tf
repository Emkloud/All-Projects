output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.this.dns_name
}

output "test_url" {
  description = "URL to access the Cafe website"
  value       = "http://${aws_lb.this.dns_name}"
}

