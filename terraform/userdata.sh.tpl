#!/bin/bash -xe

# =============================================================================
# EC2 Bootstrap Script - AWS Final Project
# Installs Apache/PHP, deploys the application, fixes the known bug
# =============================================================================

# 1. Update system packages
dnf update -y

# 2. Install Apache, PHP, and MariaDB client
dnf install -y httpd php php-mysqli mariadb105 unzip wget

# 3. Download and extract the PHP application
wget -O /tmp/Example.zip \
  "https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-200-ACACAD-3-113230/22-lab-Capstone-project/s3/Example.zip"
unzip -o /tmp/Example.zip -d /var/www/html/

# 4. Fix the lifeexpectancy.php bug
# Replace $_SESSION["ep"], $_SESSION["un"], $_SESSION["pw"], $_SESSION["db"]
# with direct variables $ep, $un, $pw, $db (same pattern as gdp.php)
sed -i 's/\$_SESSION\["ep"\]/$ep/g' /var/www/html/lifeexpectancy.php
sed -i 's/\$_SESSION\["un"\]/$un/g' /var/www/html/lifeexpectancy.php
sed -i 's/\$_SESSION\["pw"\]/$pw/g' /var/www/html/lifeexpectancy.php
sed -i 's/\$_SESSION\["db"\]/$db/g' /var/www/html/lifeexpectancy.php

# 5. Set proper permissions
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

# 6. Start and enable Apache
systemctl start httpd
systemctl enable httpd

# 7. Clean up
rm -f /tmp/Example.zip
