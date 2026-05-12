# Implementation Plan: AWS Final Project

## Overview

This plan implements a secure, scalable, and highly available three-tier PHP web application infrastructure on AWS using Terraform. The implementation is organized into incremental steps, each building on the previous, culminating in a fully wired infrastructure with documentation and validation scripts.

All Terraform code goes in `aws-final-project/terraform/`, scripts in `aws-final-project/scripts/`, application fixes in `aws-final-project/app/`, and documentation in `aws-final-project/docs/`.

## Tasks

- [x] 1. Set up project structure and Terraform provider
  - [x] 1.1 Create directory structure and providers.tf
    - Create `aws-final-project/terraform/` directory
    - Create `aws-final-project/scripts/` directory
    - Create `aws-final-project/app/` directory
    - Create `aws-final-project/docs/` directory
    - Create `aws-final-project/terraform/providers.tf` with AWS provider configured for `us-east-1` and required Terraform version constraint
    - _Requirements: 11.1, 16.1_

  - [x] 1.2 Create variables.tf with all configurable parameters
    - Define `project_prefix` (string, default "final-project")
    - Define `vpc_cidr` (string, default "10.0.0.0/16")
    - Define `aws_region` (string, default "us-east-1")
    - Define `instance_type` (string, default "t2.micro")
    - Define `db_instance_class` (string, default "db.t3.micro")
    - Define `db_name` (string, default "countries")
    - Define `asg_min` (number, default 2)
    - Define `asg_max` (number, default 4)
    - Define `asg_desired` (number, default 2)
    - Define `cpu_target` (number, default 50)
    - All variables must include descriptions
    - _Requirements: 11.2, 11.11_

- [x] 2. Implement network infrastructure
  - [x] 2.1 Create network.tf with VPC, subnets, IGW, NAT, and route tables
    - Create VPC with `var.vpc_cidr` (10.0.0.0/16), enable DNS support and hostnames
    - Create 2 public subnets (10.0.1.0/24 in us-east-1a, 10.0.2.0/24 in us-east-1b) with `map_public_ip_on_launch = true`
    - Create 2 private subnets (10.0.3.0/24 in us-east-1a, 10.0.4.0/24 in us-east-1b)
    - Create 2 DB subnets (10.0.5.0/24 in us-east-1a, 10.0.6.0/24 in us-east-1b)
    - Create Internet Gateway attached to VPC
    - Create Elastic IP and NAT Gateway in first public subnet
    - Create 3 route tables: public (route to IGW), private (route to NAT), DB (local only)
    - Associate subnets with appropriate route tables (6 associations total)
    - Use `${var.project_prefix}` naming convention for all resources
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 11.3, 11.11_

- [x] 3. Implement security groups
  - [x] 3.1 Create security_groups.tf with ALB, EC2, and RDS security groups
    - Create ALB Security Group: inbound TCP 80 from 0.0.0.0/0, outbound all traffic
    - Create EC2 Security Group: inbound TCP 80 from ALB SG only, outbound all traffic
    - Create RDS Security Group: inbound TCP 3306 from EC2 SG only, no outbound rules needed
    - No port 22 (SSH) on any security group
    - Use security group references (not CIDR) for inter-tier rules
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 1.6_

- [x] 4. Implement IAM configuration
  - [x] 4.1 Create iam.tf with role, policies, and instance profile
    - Create IAM role with `ec2.amazonaws.com` trust policy (assume role)
    - Attach `AmazonSSMManagedInstanceCore` managed policy
    - Create inline policy for Secrets Manager: `secretsmanager:GetSecretValue` and `secretsmanager:ListSecrets`
    - Create inline policy for RDS: `rds:DescribeDBInstances`
    - Create instance profile wrapping the IAM role
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 12.2_

- [x] 5. Checkpoint - Validate foundation infrastructure
  - Run `terraform validate` and `terraform fmt -check` on the terraform directory
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement RDS database
  - [x] 6.1 Create rds.tf with MySQL instance and subnet group
    - Create DB subnet group using both DB subnets
    - Create RDS MySQL 8.0 instance with:
      - Instance class: `var.db_instance_class` (db.t3.micro)
      - Database name: `var.db_name` ("countries")
      - Storage: 20 GB gp2
      - `manage_master_user_password = true` (creates rds!db- secret automatically)
      - `publicly_accessible = false`
      - VPC security group: RDS SG
      - DB subnet group reference
      - `skip_final_snapshot = true`
      - `deletion_protection = false`
      - Multi-AZ: false
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 2.1, 2.2, 2.3, 16.5_

- [x] 7. Implement Application Load Balancer
  - [x] 7.1 Create alb.tf with ALB, target group, and listener
    - Create ALB: internet-facing, application type, in both public subnets, ALB security group
    - Create target group: HTTP port 80, target type "instance", VPC reference
      - Health check: protocol HTTP, path "/", interval 30s, healthy threshold 3, unhealthy threshold 2
    - Create listener: port 80, HTTP, default action forward to target group
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 11.7_

- [x] 8. Implement Auto Scaling infrastructure
  - [x] 8.1 Create userdata.sh.tpl template script
    - Create `aws-final-project/terraform/userdata.sh.tpl` with:
      - Shebang `#!/bin/bash -xe`
      - `dnf update -y`
      - Install httpd, php, php-mysqli, mariadb105
      - Download Example.zip from S3 URL
      - Unzip to /var/www/html/
      - Apply sed bug fix for lifeexpectancy.php (replace `$_SESSION["ep"]` → `$ep`, `$_SESSION["un"]` → `$un`, `$_SESSION["pw"]` → `$pw`, `$_SESSION["db"]` → `$db`)
      - Start and enable httpd
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 14.1, 14.2, 14.4, 11.9_

  - [x] 8.2 Create autoscaling.tf with launch template, ASG, and scaling policy
    - Add `data.aws_ami` to look up latest Amazon Linux 2023 AMI
    - Create Launch Template:
      - AMI: Amazon Linux 2023 (from data source)
      - Instance type: `var.instance_type` (t2.micro)
      - Network interface: no public IP, EC2 security group
      - IAM instance profile: reference from iam.tf
      - User data: `base64encode(templatefile("userdata.sh.tpl", {}))` 
      - No key pair
    - Create ASG:
      - Min: `var.asg_min` (2), Max: `var.asg_max` (4), Desired: `var.asg_desired` (2)
      - VPC zone identifier: both private subnets
      - Health check type: "ELB", grace period: 300
      - Target group ARNs: ALB target group
      - Launch template reference (latest version)
    - Create target tracking scaling policy:
      - Metric: ASGAverageCPUUtilization
      - Target value: `var.cpu_target` (50)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 13.1, 13.2, 13.3, 13.4, 13.5, 16.2, 16.6_

- [x] 9. Implement outputs
  - [x] 9.1 Create outputs.tf with ALB DNS, RDS endpoint, and import instructions
    - Output `alb_dns_name`: ALB DNS name (access URL)
    - Output `rds_endpoint`: RDS instance endpoint address
    - Output `vpc_id`: VPC identifier
    - Output `sql_import_instructions`: Heredoc with full SSM import steps (download SQL, get credentials from Secrets Manager, get RDS endpoint, run mysql import, verify 214 rows)
    - _Requirements: 9.6, 11.10_

- [x] 10. Checkpoint - Full Terraform validation
  - Run `terraform validate` and `terraform fmt -check`
  - Run `terraform plan` to verify all resources will be created correctly
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Create SQL import script
  - [x] 11.1 Create scripts/import-data.sh for manual execution via SSM
    - Create `aws-final-project/scripts/import-data.sh` with:
      - Download Countrydatadump.sql from S3 URL
      - Retrieve secret ARN via `aws secretsmanager list-secrets --filters Key=name,Values=rds!`
      - Get secret value and parse username/password with python3 json
      - Get RDS endpoint via `aws rds describe-db-instances`
      - Run `mysql` import command
      - Verify with `SELECT COUNT(*) FROM countrydata_final;` (expect 214)
    - Make script executable and include usage comments
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 12. Create bug fix documentation
  - [x] 12.1 Create app/fix-lifeexpectancy.sh showing the sed command
    - Create `aws-final-project/app/fix-lifeexpectancy.sh` documenting:
      - The bug: `$_SESSION` variables used instead of direct variables in lifeexpectancy.php
      - The sed command that fixes it
      - Explanation of what the fix does
      - Note that this is applied automatically via user data
    - _Requirements: 14.1, 14.2, 14.3, 14.4_

- [x] 13. Create architecture documentation
  - [x] 13.1 Create docs/architecture.mmd (Mermaid diagram)
    - Create `aws-final-project/docs/architecture.mmd` with full Mermaid graph showing:
      - VPC with all subnet tiers
      - Internet Gateway, NAT Gateway
      - ALB, EC2 instances, RDS
      - Security group boundaries
      - Traffic flow arrows with port labels
      - Secrets Manager and SSM connections
    - _Requirements: 15.1_

  - [x] 13.2 Create docs/architecture.md with design decisions and evaluations
    - Create `aws-final-project/docs/architecture.md` with:
      - Architecture overview and component descriptions
      - Design decisions (single NAT, single RDS, managed credentials, no SSH)
      - Security evaluation (tier isolation, no public IPs, no SSH, IAM least privilege, encrypted credentials)
      - Scalability evaluation (ASG, target tracking, multi-AZ ALB, health checks)
      - High availability evaluation (multi-AZ, ASG replacement, ALB routing)
    - _Requirements: 15.3, 15.4, 15.5_

- [x] 14. Create README with deployment instructions
  - [x] 14.1 Create terraform/README.md with complete deployment guide
    - Create `aws-final-project/terraform/README.md` with:
      - Project overview
      - Prerequisites (Terraform, AWS CLI, Learner Lab credentials)
      - File structure explanation
      - Step-by-step deployment instructions (`terraform init`, `plan`, `apply`)
      - Post-deployment steps (SQL import via SSM)
      - Verification steps (curl ALB, check instances, test queries)
      - Cleanup instructions (`terraform destroy`)
      - Lab constraints and notes
    - _Requirements: 15.2, 15.6, 16.3, 16.4, 16.7_

- [x] 15. Final checkpoint - Complete validation
  - Run `terraform validate` and `terraform fmt -check` on all .tf files
  - Verify all files exist in correct directories
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- All implementation files go in `aws-final-project/` at the workspace root
- Spec files (requirements.md, design.md, tasks.md) remain in `.kiro/specs/aws-final-project/`
- No property-based tests are included — this is Infrastructure as Code with no pure functions to test
- Validation is done via `terraform validate`, `terraform plan`, and post-deployment smoke tests
- The SQL import is intentionally manual (via SSM) to avoid race conditions with RDS readiness
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
