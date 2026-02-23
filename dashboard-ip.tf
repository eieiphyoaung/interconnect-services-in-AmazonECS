# External data source to get dashboard public IP using AWS CLI
data "external" "dashboard_ip" {
  program = ["bash", "-c", <<-EOT
    set -e
    TASK_ARN=$(aws ecs list-tasks \
      --cluster ${aws_ecs_cluster.main.name} \
      --service-name ${aws_ecs_service.dashboard.name} \
      --query 'taskArns[0]' \
      --output text \
      --profile ${var.aws_profile} \
      --region ${var.aws_region} 2>/dev/null || echo "")
    
    if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
      echo '{"ip":"not-available","status":"no-tasks"}'
      exit 0
    fi
    
    ENI_ID=$(aws ecs describe-tasks \
      --cluster ${aws_ecs_cluster.main.name} \
      --tasks $TASK_ARN \
      --query 'tasks[0].attachments[0].details[?name==\`networkInterfaceId\`].value' \
      --output text \
      --profile ${var.aws_profile} \
      --region ${var.aws_region} 2>/dev/null || echo "")
    
    if [ -z "$ENI_ID" ]; then
      echo '{"ip":"not-available","status":"no-eni"}'
      exit 0
    fi
    
    PUBLIC_IP=$(aws ec2 describe-network-interfaces \
      --network-interface-ids $ENI_ID \
      --query 'NetworkInterfaces[0].Association.PublicIp' \
      --output text \
      --profile ${var.aws_profile} \
      --region ${var.aws_region} 2>/dev/null || echo "")
    
    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" == "None" ]; then
      echo '{"ip":"not-available","status":"no-public-ip"}'
      exit 0
    fi
    
    echo "{\"ip\":\"$PUBLIC_IP\",\"status\":\"available\"}"
  EOT
  ]

  depends_on = [aws_ecs_service.dashboard]
}
