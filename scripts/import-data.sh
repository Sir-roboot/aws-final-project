#!/bin/bash
# =============================================================================
# SQL Data Import Script for AWS Final Project
# =============================================================================
# This script imports the Countrydatadump.sql file into the RDS MySQL database.
# 
# USAGE:
#   1. Connect to an EC2 instance via SSM Session Manager:
#      aws ssm start-session --target <instance-id>
#   2. Switch to bash (SSM starts in sh):
#      bash
#   3. Run this script:
#      bash /tmp/import-data.sh
#
# PREREQUISITES:
#   - mariadb105 client installed (done by user data)
#   - EC2 instance has IAM role with Secrets Manager and RDS describe permissions
#   - RDS instance is running and accessible from the private subnet
# =============================================================================

set -e

echo "============================================"
echo "  AWS Final Project - SQL Data Import"
echo "============================================"

# Step 1: Ensure MariaDB client is installed
echo "[1/6] Checking MariaDB client..."
if ! command -v mysql &> /dev/null; then
    echo "  Installing mariadb105..."
    sudo dnf install -y mariadb105
fi
echo "  MariaDB client ready."

# Step 2: Download the SQL dump
echo "[2/6] Downloading Countrydatadump.sql..."
wget -q -O /tmp/Countrydatadump.sql \
  "https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-200-ACACAD-3-113230/22-lab-Capstone-project/s3/Countrydatadump.sql"
echo "  Download complete."

# Step 3: Retrieve secret ARN from Secrets Manager
echo "[3/6] Retrieving database credentials from Secrets Manager..."
SECRET_ARN=$(aws secretsmanager list-secrets \
  --filters Key=name,Values=rds! \
  --query "SecretList[0].ARN" \
  --output text)

if [ "$SECRET_ARN" == "None" ] || [ -z "$SECRET_ARN" ]; then
    echo "  ERROR: No secret found with prefix 'rds!'. Is RDS configured correctly?"
    exit 1
fi

# Step 4: Parse credentials
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query SecretString \
  --output text)

DB_USER=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['username'])")
DB_PWD=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['password'])")
echo "  Credentials retrieved successfully."

# Step 5: Get RDS endpoint
echo "[4/6] Getting RDS endpoint..."
RDS_HOST=$(aws rds describe-db-instances \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)

if [ "$RDS_HOST" == "None" ] || [ -z "$RDS_HOST" ]; then
    echo "  ERROR: No RDS instance found. Is the database deployed?"
    exit 1
fi
echo "  RDS endpoint: $RDS_HOST"

# Step 6: Import the SQL dump
echo "[5/6] Importing data into 'countries' database..."
mysql -h "$RDS_HOST" -u "$DB_USER" -p"$DB_PWD" countries < /tmp/Countrydatadump.sql
echo "  Import complete."

# Step 7: Verify the import
echo "[6/6] Verifying data import..."
ROW_COUNT=$(mysql -h "$RDS_HOST" -u "$DB_USER" -p"$DB_PWD" countries \
  -N -e "SELECT COUNT(*) FROM countrydata_final;")

echo ""
echo "============================================"
echo "  RESULT: $ROW_COUNT rows in countrydata_final"
echo "============================================"

if [ "$ROW_COUNT" -eq 214 ]; then
    echo "  SUCCESS: All 214 countries imported correctly."
else
    echo "  WARNING: Expected 214 rows but found $ROW_COUNT."
    exit 1
fi

# Cleanup
rm -f /tmp/Countrydatadump.sql
echo ""
echo "Done! The application should now return data for all 5 queries."
