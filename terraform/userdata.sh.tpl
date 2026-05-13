#!/bin/bash -xe

# =============================================================================
# EC2 Bootstrap Script - AWS Final Project
# Installs Apache/PHP, deploys the application, fixes the known bug,
# ensures SSM agent is running, and imports SQL data
# =============================================================================

# 1. Update system packages
dnf update -y

# 2. Install Apache, PHP, MariaDB client, and SSM agent (ensure latest)
dnf install -y httpd php php-mysqli mariadb105 unzip wget amazon-ssm-agent

# 3. Start and enable SSM agent explicitly
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# 4. Download and extract the PHP application
wget -O /tmp/Example.zip \
  "https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-200-ACACAD-3-113230/22-lab-Capstone-project/s3/Example.zip"
unzip -o /tmp/Example.zip -d /var/www/html/

# 5. Fix the lifeexpectancy.php bug
sed -i 's/\$_SESSION\["ep"\]/$ep/g' /var/www/html/lifeexpectancy.php
sed -i 's/\$_SESSION\["un"\]/$un/g' /var/www/html/lifeexpectancy.php
sed -i 's/\$_SESSION\["pw"\]/$pw/g' /var/www/html/lifeexpectancy.php
sed -i 's/\$_SESSION\["db"\]/$db/g' /var/www/html/lifeexpectancy.php

# 6. Set proper permissions
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

# 7. Start and enable Apache
systemctl start httpd
systemctl enable httpd

# 8. Import SQL data (only if not already imported)
# Wait for RDS to be available
sleep 30

SECRET_ARN=$(aws secretsmanager list-secrets --region us-east-1 --filters Key=name,Values=rds! --query "SecretList[0].ARN" --output text 2>/dev/null)
if [ -n "$SECRET_ARN" ] && [ "$SECRET_ARN" != "None" ]; then
  SECRET=$(aws secretsmanager get-secret-value --region us-east-1 --secret-id "$SECRET_ARN" --query SecretString --output text)
  DB_USER=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['username'])")
  DB_PWD=$(echo "$SECRET" | python3 -c "import json,sys; print(json.load(sys.stdin)['password'])")
  RDS_HOST=$(aws rds describe-db-instances --region us-east-1 --query "DBInstances[0].Endpoint.Address" --output text)

  if [ -n "$RDS_HOST" ] && [ "$RDS_HOST" != "None" ]; then
    # Check if data already exists
    COUNT=$(mysql -h "$RDS_HOST" -u "$DB_USER" -p"$DB_PWD" countries -N -e "SELECT COUNT(*) FROM countrydata_final;" 2>/dev/null || echo "0")
    if [ "$COUNT" -lt 214 ] 2>/dev/null; then
      wget -q -O /tmp/Countrydatadump.sql \
        "https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-200-ACACAD-3-113230/22-lab-Capstone-project/s3/Countrydatadump.sql"
      mysql -h "$RDS_HOST" -u "$DB_USER" -p"$DB_PWD" countries < /tmp/Countrydatadump.sql
      rm -f /tmp/Countrydatadump.sql
    fi
  fi
fi

# 9. Clean up
rm -f /tmp/Example.zip
