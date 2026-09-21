output "security_group_id" {
  value       = aws_security_group.app.id
  description = "Feed this into ecs-alb's security_group_id variable so the ALB and the tasks share one security group, exactly like the console walkthrough."
}

output "cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "Name of the ECS cluster."
}

output "service_name" {
  value       = aws_ecs_service.app.name
  description = "Name of the ECS service."
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.app.arn
  description = "ARN of the current task definition revision -- changes every time container_image (or cpu/memory/port) changes and gets re-applied."
}
