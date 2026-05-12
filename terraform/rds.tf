# =============================================================================
# DB Subnet Group
# =============================================================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_prefix}-db-subnet-group"
  subnet_ids = [aws_subnet.db_1.id, aws_subnet.db_2.id]

  tags = {
    Name = "${var.project_prefix}-db-subnet-group"
  }
}

# =============================================================================
# RDS MySQL Instance
# =============================================================================

resource "aws_db_instance" "main" {
  identifier     = "${var.project_prefix}-mysql"
  engine         = "mysql"
  engine_version = "8.0"

  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp2"
  db_name           = var.db_name
  username          = "admin"

  # Managed credentials in Secrets Manager (creates rds!db-... secret)
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_prefix}-mysql"
  }
}
