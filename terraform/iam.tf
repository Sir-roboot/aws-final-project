# =============================================================================
# Existing Lab IAM Instance Profile
# =============================================================================
#
# AWS Academy Learner Lab does not allow iam:CreateRole. The lab provides
# LabInstanceProfile/LabRole with the permissions needed for EC2, SSM Session
# Manager, Secrets Manager, and RDS describe calls.

data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}
