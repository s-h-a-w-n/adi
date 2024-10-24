output "app_service_endpoint" {
  description = "URL of the frontend application load balancer"
  value       = module.alb_frontend.dns_name
}

output "api_service_endpoint" {
  description = "URL of the backend application load balancer"
  value       = module.alb_backend.dns_name
}

output "deployment_role_arn" {
  value = "arn:aws:iam::678309485142:role/adi-sft-deployment-role"
}

output "frontend_load_balancer_dns_name" {
  description = "DNS name of the frontend load balancer"
  value       = module.alb_frontend.dns_name
}

output "backend_load_balancer_dns_name" {
  description = "DNS name of the backend load balancer"
  value       = module.alb_backend.dns_name
}