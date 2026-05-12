output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (access the app here)"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "Full URL to access the application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "rds_endpoint" {
  description = "RDS MySQL instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "vpc_id" {
  description = "VPC identifier"
  value       = aws_vpc.main.id
}

output "sql_import_instructions" {
  description = "Steps to import SQL data via SSM Session Manager"
  value       = <<-EOT
    ============================================================
    SQL DATA IMPORT INSTRUCTIONS
    ============================================================
    1. Connect to an EC2 instance via SSM Session Manager:
       aws ssm start-session --target <instance-id>

    2. Run the import script:
       sudo dnf install -y mariadb105
       wget https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-200-ACACAD-3-113230/22-lab-Capstone-project/s3/Countrydatadump.sql
       SECRET_ARN=$(aws secretsmanager list-secrets --filters Key=name,Values=rds! --query "SecretList[0].ARN" --output text)
       SECRET=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query SecretString --output text)
       USER=$(echo $SECRET | python3 -c "import json,sys; print(json.load(sys.stdin)['username'])")
       PWD=$(echo $SECRET | python3 -c "import json,sys; print(json.load(sys.stdin)['password'])")
       RDS_HOST=$(aws rds describe-db-instances --query "DBInstances[0].Endpoint.Address" --output text)
       mysql -h $RDS_HOST -u $USER -p$PWD countries < Countrydatadump.sql

    3. Verify (should return 214):
       mysql -h $RDS_HOST -u $USER -p$PWD countries -e "SELECT COUNT(*) FROM countrydata_final;"
    ============================================================
  EOT
}
