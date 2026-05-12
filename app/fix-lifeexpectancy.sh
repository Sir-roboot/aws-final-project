#!/bin/bash
# =============================================================================
# Bug Fix: lifeexpectancy.php (Query 3 - Life Expectancy)
# =============================================================================
#
# PROBLEM:
#   The file lifeexpectancy.php in Example.zip has a bug on line 6.
#   It uses $_SESSION["ep"], $_SESSION["un"], $_SESSION["pw"], $_SESSION["db"]
#   to create the database connection, but these session variables are never
#   initialized. This causes Query 3 (Life Expectancy) to return empty results.
#
#   All other query files (gdp.php, population.php, etc.) use direct variables
#   ($ep, $un, $pw, $db) which are set by get-parameters.php.
#
# BROKEN CODE (line 6 of lifeexpectancy.php):
#   $conn = new mysqli($_SESSION["ep"], $_SESSION["un"], $_SESSION["pw"], $_SESSION["db"]);
#
# FIXED CODE:
#   $conn = new mysqli($ep, $un, $pw, $db);
#
# FIX COMMAND:
#   This sed command replaces all $_SESSION references with direct variables.
#   It is idempotent - running it multiple times has no additional effect.
#
# NOTE:
#   This fix is applied AUTOMATICALLY by the EC2 User Data script during
#   instance bootstrap. Every new instance launched by the Auto Scaling Group
#   will have this fix applied. No manual intervention is needed.
#
# =============================================================================

# Apply the fix
sed -i 's/\$_SESSION\["ep"\]/$ep/g' /var/www/html/lifeexpectancy.php
sed -i 's/\$_SESSION\["un"\]/$un/g' /var/www/html/lifeexpectancy.php
sed -i 's/\$_SESSION\["pw"\]/$pw/g' /var/www/html/lifeexpectancy.php
sed -i 's/\$_SESSION\["db"\]/$db/g' /var/www/html/lifeexpectancy.php

echo "Bug fix applied to lifeexpectancy.php"
echo "Query 3 (Life Expectancy) should now return data correctly."
