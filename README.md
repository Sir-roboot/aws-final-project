# AWS Final Project

Infrastructure and documentation for the AWS Academy final project: a secure and scalable PHP application deployed on AWS.

## Contents

- `specs/`: requirements, design, and implementation tasks.
- `terraform/`: Terraform infrastructure for VPC, ALB, private EC2 Auto Scaling Group, RDS MySQL, security groups, and supporting resources.
- `scripts/`: helper script for importing the SQL data dump into RDS.
- `app/`: notes/scripts related to the PHP application fix.
- `docs/`: architecture diagram in Mermaid and draw.io formats.

## High-Level Architecture

The solution uses a three-tier AWS architecture:

- Public subnets host the Application Load Balancer and NAT Gateway.
- Private application subnets host EC2 instances running Apache and PHP through an Auto Scaling Group.
- Private database subnets host Amazon RDS MySQL with database name `countries`.
- AWS Secrets Manager stores RDS credentials.
- AWS Systems Manager Session Manager is used for administrative access.

## Deploy

```powershell
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

After deployment:

```powershell
terraform output -raw alb_url
```

Import the SQL data dump from an EC2 instance through SSM using `scripts/import-data.sh` or the instructions in `terraform/README.md`.

## Important

Do not commit Terraform state files, AWS credentials, `.tfvars`, or local secrets. This repository intentionally ignores those files.
