# AWS Security & Compliance

Best practices for securing Amazon Web Services infrastructure and meeting compliance requirements.

---

## Security Principles

### Defense in Depth
1. **Identity & Access Management (IAM)**: Least privilege access, no root account usage
2. **Network Security**: Security groups, NACLs, private subnets
3. **Data Protection**: Encryption at rest and in transit, KMS
4. **Monitoring & Logging**: CloudTrail, CloudWatch, GuardDuty
5. **Compliance**: Industry standards (HIPAA, PCI-DSS, SOC 2)

---

## Identity & Access Management (IAM)

### Least Privilege Principle
```hcl
# Good: Specific, minimal permissions
resource "aws_iam_role" "lambda" {
  name = "api-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
      ]
      Resource = aws_dynamodb_table.users.arn
    }]
  })
}

# Bad: Overly broad permissions
resource "aws_iam_role_policy_attachment" "bad" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"  # ❌ Never use
}
```

### IAM Best Practices
```hcl
# 1. Enable MFA for all users
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
}

# 2. Use IAM roles, not access keys
# Lambda automatically uses IAM role
resource "aws_lambda_function" "api" {
  role = aws_iam_role.lambda.arn
  # No access keys needed!
}

# 3. Use IAM roles for EC2 (instance profiles)
resource "aws_iam_instance_profile" "app" {
  name = "app-instance-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "app" {
  ami                  = "ami-0c55b159cbfafe1f0"
  instance_type        = "t4g.medium"
  iam_instance_profile = aws_iam_instance_profile.app.name
  # No access keys in environment variables or code!
}

# 4. Use IAM Roles for Service Accounts (IRSA) in EKS
resource "aws_iam_role" "k8s_service_account" {
  name = "k8s-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:default:app-sa"
        }
      }
    }]
  })
}
```

**No Access Keys Policy**:
- ✅ Use IAM roles for AWS resources (Lambda, EC2, ECS)
- ✅ Use IRSA for EKS pods
- ✅ Use OIDC for GitHub Actions / CI/CD
- ❌ Never commit access keys to Git
- ❌ Never use root account access keys

### Service Control Policies (SCPs) for AWS Organizations
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances"
      ],
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringNotEquals": {
          "ec2:InstanceType": [
            "t3.micro",
            "t3.small",
            "t3.medium",
            "t4g.micro",
            "t4g.small",
            "t4g.medium"
          ]
        }
      }
    },
    {
      "Effect": "Deny",
      "Action": [
        "iam:CreateAccessKey"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## Network Security

### VPC Design
```hcl
# Good: Defense in depth with security groups and NACLs
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Private subnets (no internet gateway route)
resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false  # No public IPs

  tags = {
    Name = "private-${count.index + 1}"
  }
}

# Security group: Default deny all, explicit allow
resource "aws_security_group" "app" {
  name        = "app-sg"
  description = "Application security group"
  vpc_id      = aws_vpc.main.id

  # No ingress rules by default (deny all)

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Explicit allow rules
resource "aws_security_group_rule" "app_from_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.app.id
}

# Network ACL (additional layer of defense)
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Allow traffic from VPC
  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = aws_vpc.main.cidr_block
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}
```

### VPC Flow Logs
```hcl
# Enable VPC Flow Logs for traffic analysis
resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 30
}
```

### AWS WAF (Web Application Firewall)
```hcl
# Protect against common web exploits
resource "aws_wafv2_web_acl" "main" {
  name  = "api-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rules
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting (DDoS protection)
  rule {
    name     = "RateLimitRule"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000  # requests per 5 minutes
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ApiWafMetric"
    sampled_requests_enabled   = true
  }
}

# Associate with ALB
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
```

---

## Data Protection

### Encryption at Rest (KMS)
```hcl
# Create KMS key
resource "aws_kms_key" "app" {
  description             = "Application encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow services to use the key"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "s3.amazonaws.com",
            "rds.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "app" {
  name          = "alias/app-key"
  target_key_id = aws_kms_key.app.key_id
}

# Use KMS key for S3 encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "encrypted" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.app.arn
    }
    bucket_key_enabled = true
  }
}

# Use KMS key for RDS encryption
resource "aws_db_instance" "encrypted" {
  storage_encrypted = true
  kms_key_id        = aws_kms_key.app.arn
  # ... other config
}

# Use KMS key for EBS encryption
resource "aws_ebs_volume" "encrypted" {
  encrypted  = true
  kms_key_id = aws_kms_key.app.arn
  # ... other config
}
```

### Encryption in Transit
```hcl
# Application Load Balancer with TLS
resource "aws_lb" "main" {
  name               = "app-alb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"  # TLS 1.3
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Redirect HTTP to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# RDS: Enforce SSL connections
resource "aws_db_instance" "postgres" {
  # ... other config

  # Create parameter group that enforces SSL
  parameter_group_name = aws_db_parameter_group.postgres_ssl.name
}

resource "aws_db_parameter_group" "postgres_ssl" {
  family = "postgres15"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}
```

### Secrets Management
```hcl
# Good: Use Secrets Manager for sensitive data
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.environment}/db-password"
  recovery_window_in_days = 7

  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password  # Injected from CI/CD, never committed
}

# Lambda function access
resource "aws_iam_role_policy" "lambda_secrets" {
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
      ]
      Resource = aws_secretsmanager_secret.db_password.arn
    }]
  })
}
```

```typescript
// Retrieve secret in Lambda
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

const client = new SecretsManagerClient({});

async function getDbPassword(): Promise<string> {
  const response = await client.send(new GetSecretValueCommand({
    SecretId: process.env.DB_PASSWORD_SECRET_ARN,
  }));

  return response.SecretString!;
}
```

---

## Monitoring & Logging

### CloudTrail - Audit Logging
```hcl
# Enable CloudTrail for all API calls
resource "aws_cloudtrail" "main" {
  name                          = "org-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    # Log data events (S3, Lambda)
    data_resource {
      type = "AWS::S3::Object"
      values = ["arn:aws:s3:::${aws_s3_bucket.sensitive_data.id}/"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }

  # Send logs to CloudWatch
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn
}

# Store CloudTrail logs in encrypted S3
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "my-org-cloudtrail-logs"
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.cloudtrail.arn
    }
  }
}
```

### GuardDuty - Threat Detection
```hcl
# Enable GuardDuty
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }
}

# Send findings to SNS
resource "aws_cloudwatch_event_rule" "guardduty" {
  name        = "guardduty-findings"
  description = "GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [7, 8, 9]  # High severity only
    }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.guardduty.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}
```

### Config - Compliance Monitoring
```hcl
# AWS Config for compliance checks
resource "aws_config_configuration_recorder" "main" {
  name     = "config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# Config rule: Ensure S3 buckets are encrypted
resource "aws_config_config_rule" "s3_encrypted" {
  name = "s3-bucket-server-side-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Config rule: Ensure RDS instances are encrypted
resource "aws_config_config_rule" "rds_encrypted" {
  name = "rds-storage-encrypted"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}
```

---

## Compliance

### HIPAA Compliance
**Requirements**:
1. Sign Business Associate Addendum (BAA) with AWS
2. Use HIPAA-eligible services only
3. Encrypt PHI at rest and in transit (KMS, TLS)
4. Enable audit logging (CloudTrail, VPC Flow Logs)
5. Access controls (IAM, security groups)
6. Backup and disaster recovery

**HIPAA-Eligible Services**:
- ✅ EC2, ECS, EKS, Lambda
- ✅ S3, EBS, RDS, DynamoDB
- ✅ KMS, Secrets Manager, CloudTrail
- ❌ Lightsail, WorkSpaces, Comprehend Medical (not eligible)

### PCI-DSS Compliance
**Key Controls**:
1. Network segmentation (VPC, security groups)
2. Encryption (KMS for cardholder data)
3. Access controls (IAM least privilege)
4. Audit logging (CloudTrail, VPC Flow Logs)
5. Vulnerability management (AWS Inspector)

**AWS PCI DSS Compliance**:
- AWS provides PCI DSS Level 1 Service Provider certification
- Download Attestation of Compliance (AOC) from AWS Artifact

### SOC 2 Compliance
**AWS provides**:
- SOC 2 Type II reports
- ISO 27001 certification
- Annual audits

**Your responsibilities**:
- Configure services securely (IAM, encryption)
- Enable logging and monitoring
- Implement access controls
- Regular security reviews

---

## Security Checklist

### IAM
- [ ] Enable MFA for all users
- [ ] Use IAM roles (no access keys)
- [ ] Apply least privilege principle
- [ ] Use IRSA for EKS pods
- [ ] Regular IAM access review

### Network
- [ ] Use private subnets for apps and databases
- [ ] Security groups: default deny, explicit allow
- [ ] Enable VPC Flow Logs
- [ ] Use AWS WAF for public APIs
- [ ] Use TLS 1.3 for all traffic

### Data Protection
- [ ] Enable encryption at rest (KMS)
- [ ] Enforce encryption in transit (TLS)
- [ ] Use Secrets Manager (not environment variables)
- [ ] Enable S3 versioning and MFA Delete
- [ ] Backup and disaster recovery plan

### Monitoring
- [ ] Enable CloudTrail (all regions)
- [ ] Enable GuardDuty (threat detection)
- [ ] Enable AWS Config (compliance checks)
- [ ] Set up security alerts (SNS, email)
- [ ] Regular security audits

### Compliance
- [ ] Sign BAA for HIPAA
- [ ] Download PCI DSS AOC from AWS Artifact
- [ ] Download SOC 2 reports
- [ ] Document security controls
- [ ] Incident response plan

---

## Tools

### AWS Native
- **GuardDuty**: Threat detection
- **AWS WAF**: Web application firewall
- **Shield**: DDoS protection
- **Inspector**: Vulnerability scanning
- **Macie**: Sensitive data discovery
- **Security Hub**: Centralized security findings
- **CloudTrail**: Audit logging
- **Config**: Compliance monitoring

### Third-Party
- **Wiz**: Cloud security posture management
- **Lacework**: Cloud workload protection
- **Snyk**: Container vulnerability scanning
- **Falco**: Runtime security for Kubernetes
- **Prowler**: AWS security best practices assessment

---

## References

- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [HIPAA on AWS](https://aws.amazon.com/compliance/hipaa-compliance/)
- [PCI DSS on AWS](https://aws.amazon.com/compliance/pci-dss-level-1-faqs/)
- [AWS Security Hub](https://aws.amazon.com/security-hub/)
