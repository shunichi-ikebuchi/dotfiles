# AWS Cost Optimization

Strategies and best practices for minimizing cloud costs while maintaining performance and reliability.

---

## Cost Management Principles

### Core Strategies
1. **Right-size resources**: Match resources to actual needs
2. **Use Savings Plans & Reserved Instances**: Save 30-72% on predictable workloads
3. **Leverage autoscaling**: Scale down during low traffic
4. **Use Spot Instances**: Save up to 90% for fault-tolerant workloads
5. **Optimize storage**: Use appropriate storage classes and lifecycle policies
6. **Monitor and alert**: Set budgets and track spending

---

## Compute Optimization

### Lambda - Serverless Cost Efficiency
```typescript
// Good: Optimized Lambda configuration
import { Duration } from 'aws-cdk-lib';
import * as lambda from 'aws-cdk-lib/aws-lambda';

new lambda.Function(this, 'ApiFunction', {
  runtime: lambda.Runtime.NODEJS_20_X,
  architecture: lambda.Architecture.ARM_64,  // Graviton2: 20% cheaper
  memorySize: 512,  // Right-size (test to find optimal)
  timeout: Duration.seconds(30),  // Don't over-provision
  reservedConcurrentExecutions: 10,  // Limit max concurrent (control costs)
});
```

**Lambda Pricing**:
- **Requests**: $0.20 per 1M requests
- **Compute**: $0.0000166667 per GB-second (x86), $0.0000133334 (Arm/Graviton2)
- **Free Tier**: 1M requests + 400,000 GB-seconds/month

**Cost Optimization Tips**:
- ✅ Use Arm/Graviton2 (20% cheaper, same performance)
- ✅ Right-size memory (test optimal size, don't over-provision)
- ✅ Reduce cold starts with Provisioned Concurrency (if needed)
- ✅ Use Lambda Layers for shared dependencies (smaller packages)
- ✅ Set appropriate timeouts (don't waste time on hanging requests)

**When Lambda costs too much**:
- If running 24/7 with high traffic → Use Fargate or EC2
- If execution time >15 min → Use Fargate or Step Functions

### EC2 - Instance Optimization

#### Savings Plans & Reserved Instances
```
Pricing Comparison (m5.large in us-east-1):
- On-Demand: $0.096/hour = $70.08/month
- Savings Plan (1-year): $0.062/hour = $45.26/month (35% savings)
- Savings Plan (3-year): $0.041/hour = $29.93/month (57% savings)
- Reserved Instance (3-year, all upfront): $0.037/hour = $27.01/month (61% savings)
- Spot Instance: $0.029/hour = $21.17/month (70% savings)
```

**Recommendation**:
- Use **Savings Plans** (more flexible than Reserved Instances)
- Use **Spot Instances** for fault-tolerant workloads (batch jobs, dev/test)

#### Instance Type Selection
```hcl
# Good: Cost-optimized instance types
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t4g.medium"  # Graviton2: 20% cheaper than t3

  # Enable detailed monitoring only if needed (costs extra)
  monitoring = false

  root_block_device {
    volume_type = "gp3"  # 20% cheaper than gp2
    volume_size = 20     # Right-size disk
  }
}
```

**Instance Family Guide**:
| Family | Use Case | Cost Efficiency |
|--------|----------|----------------|
| **t4g/t3** | Burstable, general purpose | ⭐⭐⭐ Best for variable workloads |
| **m6g/m6i** | General purpose | ⭐⭐⭐ Good balance |
| **c6g/c6i** | Compute-optimized | ⭐⭐ Use only if CPU-bound |
| **r6g/r6i** | Memory-optimized | ⭐⭐ Use only if memory-bound |
| **Graviton (g suffix)** | ARM-based | ⭐⭐⭐ 20% cheaper than x86 |

#### Spot Instances for Batch Workloads
```hcl
# Good: Spot instances for fault-tolerant workloads
resource "aws_autoscaling_group" "batch_workers" {
  name                = "batch-workers"
  min_size            = 0
  max_size            = 100
  desired_capacity    = 10
  vpc_zone_identifier = var.private_subnet_ids

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0  # 100% Spot
      spot_allocation_strategy                 = "price-capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.batch.id
        version            = "$Latest"
      }

      # Diversify across instance types (better Spot availability)
      override {
        instance_type = "m6g.large"
      }
      override {
        instance_type = "m6i.large"
      }
      override {
        instance_type = "m5.large"
      }
    }
  }
}
```

**Spot Instance Best Practices**:
- ✅ Diversify instance types (better availability)
- ✅ Use `price-capacity-optimized` allocation strategy
- ✅ Handle interruptions gracefully (2-minute warning via metadata)
- ✅ Ideal for: Batch jobs, CI/CD, data processing, dev/test
- ❌ Not for: Databases, critical production services

### ECS Fargate - Spot Capacity
```hcl
resource "aws_ecs_service" "app" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 10

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 70  # 70% on Spot (up to 70% savings)
    base              = 0
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 30  # 30% on regular Fargate (stable)
    base              = 2   # Always keep 2 tasks on regular
  }
}
```

### EKS - Node Cost Optimization
```hcl
# Good: EKS managed node group with Spot
resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "spot-workers"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = ["t4g.large", "t3.large", "m6g.large"]  # Diversify
  capacity_type  = "SPOT"

  scaling_config {
    desired_size = 5
    max_size     = 50
    min_size     = 0  # Scale to zero when idle
  }

  labels = {
    workload = "batch"
  }

  taint {
    key    = "spot"
    value  = "true"
    effect = "NO_SCHEDULE"  # Only schedule Spot-tolerant workloads
  }
}
```

---

## Storage Optimization

### S3 - Lifecycle Policies
```hcl
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    # Move to Infrequent Access after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"  # 50% cheaper
    }

    # Move to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"  # 90% cheaper
    }

    # Delete after 1 year
    expiration {
      days = 365
    }
  }

  rule {
    id     = "delete-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Intelligent-Tiering (automatic cost optimization)
resource "aws_s3_bucket_intelligent_tiering_configuration" "auto" {
  bucket = aws_s3_bucket.data.id
  name   = "auto-archive"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}
```

**S3 Storage Class Pricing** (per GB/month in us-east-1):
| Class | Price | Retrieval | Use Case |
|-------|-------|-----------|----------|
| **Standard** | $0.023 | None | Frequent access |
| **Intelligent-Tiering** | $0.023 + $0.0025 monitoring | None | Unknown access pattern |
| **Standard-IA** | $0.0125 | $0.01/GB | Infrequent access |
| **One Zone-IA** | $0.01 | $0.01/GB | Infrequent, non-critical |
| **Glacier Instant** | $0.004 | $0.03/GB | Archive, instant retrieval |
| **Glacier Flexible** | $0.0036 | $0.03/GB + time | Archive, 1-5 min retrieval |
| **Glacier Deep Archive** | $0.00099 | $0.02/GB + time | Long-term, 12-hour retrieval |

### EBS Volume Optimization
```hcl
# Good: Right-sized EBS volumes
resource "aws_ebs_volume" "data" {
  availability_zone = "us-east-1a"
  size              = 100
  type              = "gp3"  # 20% cheaper than gp2, better performance

  # gp3 allows independent IOPS and throughput configuration
  iops       = 3000  # Default: 3000 (free)
  throughput = 125   # Default: 125 MB/s (free)

  tags = {
    Name = "data-volume"
  }
}

# Delete on instance termination
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t4g.medium"

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true  # Don't leave orphaned volumes
  }
}
```

**EBS Volume Type Costs** (per GB-month in us-east-1):
- **gp3** (SSD): $0.08/GB (recommended for most workloads)
- **gp2** (SSD): $0.10/GB
- **io2** (SSD, provisioned IOPS): $0.125/GB + $0.065 per IOPS
- **st1** (HDD, throughput-optimized): $0.045/GB
- **sc1** (HDD, cold): $0.015/GB

### RDS - Database Cost Optimization
```hcl
resource "aws_db_instance" "postgres" {
  identifier        = "prod-db"
  engine            = "postgres"
  engine_version    = "15.3"
  instance_class    = "db.t4g.large"  # Graviton2: 20% cheaper
  allocated_storage = 100
  storage_type      = "gp3"  # 20% cheaper than gp2

  # Multi-AZ only for production
  multi_az = var.environment == "prod" ? true : false

  # Automated backups
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Enable Performance Insights only if needed (extra cost)
  performance_insights_enabled = false

  # Delete protection for production
  deletion_protection = var.environment == "prod" ? true : false

  # Automated minor version upgrades
  auto_minor_version_upgrade = true
}

# Stop dev/staging databases when not in use
resource "aws_lambda_function" "stop_db" {
  # Schedule with EventBridge to stop DB at night
  # Save ~70% on non-production databases
}
```

**RDS Cost Tips**:
- ✅ Use Graviton-based instances (db.t4g, db.m6g) for 20% savings
- ✅ Use gp3 storage (cheaper than gp2)
- ✅ Use Aurora Serverless v2 for variable workloads (auto-scaling)
- ✅ Stop dev/staging databases when not in use
- ✅ Use read replicas instead of larger primary
- ✅ Use Reserved Instances for production (40-60% savings)

---

## Network Optimization

### Minimize Data Transfer Costs
```
Data Transfer Pricing:
- In: Free
- Out to Internet: $0.09/GB (first 10 TB)
- Out to CloudFront: Free (use CDN!)
- Same AZ: Free
- Different AZ: $0.01/GB (each direction)
- Different Region: $0.02/GB
```

**Cost Saving Strategies**:
```hcl
# 1. Use CloudFront for static assets (no egress charges)
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id   = "S3-static"
  }

  enabled = true

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-static"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true  # Reduce bandwidth

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
}

# 2. Keep resources in same AZ (free data transfer)
resource "aws_instance" "app" {
  availability_zone = "us-east-1a"
  subnet_id         = aws_subnet.private_a.id
}

resource "aws_rds_instance" "db" {
  availability_zone = "us-east-1a"  # Same AZ as app
  # Saves $0.01/GB on data transfer
}

# 3. Use VPC endpoints for AWS services (no internet egress)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"
  route_table_ids = [aws_route_table.private.id]
}
```

### NAT Gateway Cost Optimization
```
NAT Gateway Pricing:
- $0.045/hour = $32.40/month
- $0.045/GB processed

For high-traffic workloads, NAT Gateway can be very expensive!
```

**Alternatives**:
```hcl
# Option 1: Use VPC endpoints (free data transfer for AWS services)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.dynamodb"
}

# Option 2: NAT instance (cheaper for low traffic, requires management)
resource "aws_instance" "nat" {
  ami           = "ami-nat-instance"  # Use Amazon NAT AMI
  instance_type = "t4g.nano"  # $3.07/month (vs $32.40 for NAT Gateway)
  source_dest_check = false
}

# Option 3: Share NAT Gateway across environments (dev/staging)
# For production, use dedicated NAT Gateway per AZ for reliability
```

---

## Monitoring & Alerting

### AWS Budgets
```hcl
resource "aws_budgets_budget" "monthly" {
  name         = "monthly-budget"
  budget_type  = "COST"
  limit_amount = "1000"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["finance@company.com"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["finance@company.com"]
  }
}
```

### Cost Allocation Tags
```hcl
# Tag all resources for cost tracking
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t4g.medium"

  tags = {
    Environment = "production"
    Team        = "backend"
    Project     = "api-service"
    CostCenter  = "engineering"
  }
}

# Enable cost allocation tags in billing console
# Then create Cost and Usage Reports by tag
```

---

## Cost Optimization Checklist

### Compute
- [ ] Use Savings Plans or Reserved Instances for steady workloads
- [ ] Use Spot Instances for fault-tolerant workloads (batch, CI/CD)
- [ ] Use Graviton instances (t4g, m6g, etc.) for 20% savings
- [ ] Right-size instances (use Compute Optimizer recommendations)
- [ ] Use Lambda for sporadic workloads (scale to zero)
- [ ] Stop/terminate unused resources (dev/staging)

### Storage
- [ ] Use S3 lifecycle policies (Intelligent-Tiering, Glacier)
- [ ] Use gp3 instead of gp2 for EBS volumes
- [ ] Delete unused EBS snapshots and volumes
- [ ] Use S3 Intelligent-Tiering for unknown access patterns
- [ ] Compress data before storing in S3

### Database
- [ ] Use Graviton-based RDS instances (db.t4g, db.m6g)
- [ ] Use Reserved Instances for production databases
- [ ] Stop dev/staging databases when not in use
- [ ] Use read replicas instead of larger primary
- [ ] Use Aurora Serverless v2 for variable workloads

### Network
- [ ] Use CloudFront for static assets (no egress charges)
- [ ] Keep resources in same AZ when possible
- [ ] Use VPC endpoints for AWS services
- [ ] Minimize cross-region traffic
- [ ] Consider NAT instance for low-traffic dev/staging

### Monitoring
- [ ] Set up AWS Budgets with alerts
- [ ] Enable Cost Allocation Tags
- [ ] Review Cost Explorer monthly
- [ ] Use Trusted Advisor (Business/Enterprise support)
- [ ] Use Compute Optimizer for right-sizing recommendations

---

## Tools

### AWS Native
- **Cost Explorer**: Visualize spending by service, tag, etc.
- **Budgets**: Set spending limits and alerts
- **Cost and Usage Reports**: Detailed billing data
- **Trusted Advisor**: Cost optimization recommendations
- **Compute Optimizer**: Right-sizing recommendations

### Third-Party
- **CloudHealth**: Multi-cloud cost management
- **Cloudability**: Cost analytics and optimization
- **Infracost**: Show cost estimates in pull requests (for Terraform)
- **Kubecost**: Kubernetes cost monitoring (for EKS)

---

## References

- [AWS Pricing Calculator](https://calculator.aws/)
- [AWS Cost Optimization](https://aws.amazon.com/pricing/cost-optimization/)
- [Savings Plans](https://aws.amazon.com/savingsplans/)
- [EC2 Spot Instances](https://aws.amazon.com/ec2/spot/)
