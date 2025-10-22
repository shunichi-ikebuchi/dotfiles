# GCP Cost Optimization

Strategies and best practices for minimizing cloud costs while maintaining performance and reliability.

---

## Cost Management Principles

### Core Strategies
1. **Right-size resources**: Match resources to actual needs
2. **Use committed use discounts**: Save 20-57% on predictable workloads
3. **Leverage autoscaling**: Scale down during low traffic
4. **Use preemptible/spot instances**: Save up to 91% for fault-tolerant workloads
5. **Optimize storage**: Use appropriate storage classes and lifecycle policies
6. **Monitor and alert**: Set budgets and track spending

---

## Compute Optimization

### Cloud Run - Serverless Cost Efficiency
```yaml
# Good: Optimized Cloud Run configuration
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: api-service
spec:
  template:
    metadata:
      annotations:
        # Scale to zero when idle (pay nothing!)
        autoscaling.knative.dev/minScale: "0"
        # Limit max instances to control costs
        autoscaling.knative.dev/maxScale: "10"
        # Increase concurrent requests per instance (reduce instances needed)
        autoscaling.knative.dev/target: "80"
    spec:
      containers:
      - image: gcr.io/project/api:v1
        resources:
          limits:
            # Right-size CPU (don't over-provision)
            cpu: "1000m"
            # Right-size memory (billed per 128MB increments)
            memory: "512Mi"  # Use 512, 768, 1024, etc. (not 600)
        startupProbe:
          # Fast startup = less billed time
          httpGet:
            path: /health
          initialDelaySeconds: 0
          periodSeconds: 1
          failureThreshold: 10
```

**Cost Savings**:
- ✅ Scale to zero: No cost when idle
- ✅ CPU always allocated: Pay only during request processing
- ✅ 100ms billing granularity: Fine-grained charging
- ✅ No infrastructure management: No wasted capacity

**When Cloud Run costs too much**:
- If traffic is steady 24/7, consider GKE with committed use
- If requests are very long (>15 min), consider Compute Engine

### GKE - Kubernetes Cost Optimization

#### Autopilot (Recommended)
```yaml
# Good: GKE Autopilot - pay per pod resources
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: api
        image: gcr.io/project/api:v1
        resources:
          requests:  # Billed based on requests (not limits)
            cpu: "250m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
```

**Autopilot Benefits**:
- ✅ Pay per pod (no wasted node capacity)
- ✅ Auto-scaling (vertical and horizontal)
- ✅ No node management overhead
- ✅ Automatic bin-packing (efficient resource usage)

#### Standard GKE - Cost Controls
```hcl
# Good: Standard GKE with cost controls
resource "google_container_cluster" "primary" {
  name     = "prod-cluster"
  location = "us-central1"

  # Use regional cluster only if you need HA (more expensive than zonal)
  # For dev/staging, use zonal cluster

  node_config {
    # Use E2 instances (cheaper than N1)
    machine_type = "e2-standard-4"

    # Enable preemptible nodes for non-critical workloads
    preemptible = true

    # Use spot VMs (newer, more available than preemptible)
    spot = true
  }

  # Cluster autoscaling
  cluster_autoscaling {
    enabled = true
    autoscaling_profile = "OPTIMIZE_UTILIZATION"  # Aggressive scale-down

    resource_limits {
      resource_type = "cpu"
      minimum       = 4
      maximum       = 100
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 16
      maximum       = 400
    }
  }
}
```

### Compute Engine - VM Cost Optimization

```hcl
# Good: Cost-optimized VM
resource "google_compute_instance" "worker" {
  name         = "batch-worker"
  machine_type = "e2-medium"  # E2: best price/performance
  zone         = "us-central1-a"

  # Preemptible: up to 91% cheaper (max 24h runtime)
  scheduling {
    preemptible       = true
    automatic_restart = false
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10  # Right-size disk (default is often too large)
      type  = "pd-standard"  # SSD only if needed (3x more expensive)
    }
  }
}

# Committed use discount (apply via console or API)
# 1-year: 25% discount
# 3-year: 52% discount
```

**Machine Type Selection**:
| Type | Use Case | Cost Efficiency |
|------|----------|----------------|
| **E2** | General purpose | ⭐⭐⭐ Best value |
| **N2** | Balanced performance | ⭐⭐ Good for most workloads |
| **N2D** | AMD-based, cheaper | ⭐⭐⭐ High performance/cost |
| **C2** | Compute-intensive | ⭐ Expensive, specific use cases |
| **M2** | Memory-intensive | ⭐ Expensive, specific use cases |

---

## Storage Optimization

### Cloud Storage - Lifecycle Policies
```hcl
resource "google_storage_bucket" "data" {
  name     = "my-data-bucket"
  location = "US"

  # Lifecycle rules to move old data to cheaper storage
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"  # ~50% cheaper
    }
    condition {
      age = 30  # Move to nearline after 30 days
    }
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"  # ~75% cheaper
    }
    condition {
      age = 90  # Move to coldline after 90 days
    }
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365  # Delete after 1 year
    }
  }
}
```

**Storage Class Pricing** (per GB/month):
| Class | Price | Retrieval Cost | Use Case |
|-------|-------|----------------|----------|
| **Standard** | $0.020 | None | Frequent access |
| **Nearline** | $0.010 | $0.01/GB | Monthly access |
| **Coldline** | $0.004 | $0.02/GB | Quarterly access |
| **Archive** | $0.0012 | $0.05/GB | Annual access |

### BigQuery - Cost Control

```sql
-- Good: Partitioned + clustered table (reduce scanned data)
CREATE TABLE analytics.events (
  event_id STRING,
  user_id STRING,
  event_type STRING,
  event_data JSON,
  event_timestamp TIMESTAMP
)
PARTITION BY DATE(event_timestamp)
CLUSTER BY user_id, event_type
OPTIONS(
  partition_expiration_days=90,  -- Auto-delete old partitions
  require_partition_filter=true   -- Force partition filter (prevent full scans)
);

-- Good: Query with partition filter (scan only 1 day)
SELECT COUNT(*)
FROM analytics.events
WHERE DATE(event_timestamp) = '2024-01-15'  -- Partition filter!
  AND event_type = 'purchase';

-- Bad: Full table scan (expensive!)
SELECT COUNT(*)
FROM analytics.events
WHERE event_type = 'purchase';  -- ❌ Scans all data
```

**BigQuery Cost Savings**:
- ✅ Use partitioning: Reduce scanned data by 90%+
- ✅ Use clustering: Further reduce scanned data
- ✅ Use `LIMIT` for exploratory queries
- ✅ Avoid `SELECT *` (select only needed columns)
- ✅ Use materialized views for repeated queries
- ✅ Use BI Engine for dashboard queries (flat-rate pricing)

**Pricing**:
- On-demand: $5 per TB scanned
- Flat-rate: $2,000-10,000/month (unlimited queries)
- Storage: $0.02/GB/month (active), $0.01/GB/month (long-term)

**When to use flat-rate**:
- Scanning >400 TB/month
- Unpredictable query patterns
- Need cost predictability

---

## Database Optimization

### Cloud SQL - Instance Right-Sizing
```hcl
resource "google_sql_database_instance" "postgres" {
  name             = "prod-db"
  database_version = "POSTGRES_15"
  region           = "us-central1"

  settings {
    # Right-size tier (don't over-provision)
    tier = "db-custom-2-7680"  # 2 vCPU, 7.5 GB RAM

    # Automated backups (cheaper than manual snapshots)
    backup_configuration {
      enabled    = true
      start_time = "03:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 7  # Don't keep too many backups
      }
    }

    # Insights (helps identify slow queries to optimize)
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
    }

    # Storage autoresize (grow as needed)
    disk_autoresize = true
    disk_size       = 10  # Start small, grow automatically
    disk_type       = "PD_SSD"  # Use HDD for dev (cheaper)
  }
}
```

**Cloud SQL Cost Tips**:
- ✅ Use read replicas instead of larger primary
- ✅ Schedule downtime for dev/staging instances (stop when not used)
- ✅ Use connection pooling (reduce instance size)
- ✅ Consider Cloud Spanner only for global scale (much more expensive)

---

## Network Optimization

### Minimize Egress Costs
```
Egress Pricing (per GB):
- Same zone: Free
- Same region (different zone): $0.01
- Different region (same continent): $0.01
- Internet egress: $0.12 - $0.23 (varies by region)
```

**Cost Saving Strategies**:
```hcl
# Good: Keep data in same region
resource "google_storage_bucket" "data" {
  name     = "my-data"
  location = "us-central1"  # Same region as Cloud Run/GKE
}

resource "google_cloud_run_service" "api" {
  location = "us-central1"  # Same region as bucket
}

# Bad: Cross-region access (expensive egress)
# Bucket in "europe-west1", Cloud Run in "us-central1"
```

**CDN for Static Assets**:
```hcl
# Use Cloud CDN to reduce egress costs
resource "google_compute_backend_bucket" "cdn" {
  name        = "cdn-backend"
  bucket_name = google_storage_bucket.static.name
  enable_cdn  = true

  cdn_policy {
    cache_mode = "CACHE_ALL_STATIC"
    default_ttl = 3600
    max_ttl     = 86400
  }
}
```

### Load Balancer Costs
- HTTP(S) Load Balancer: $0.025/hour + $0.008-0.010 per GB processed
- Network Load Balancer: Cheaper, but Layer 4 only

**Tip**: Use Cloud Run's built-in load balancing (free) instead of external load balancer when possible.

---

## Monitoring & Alerting

### Budget Alerts
```hcl
resource "google_billing_budget" "project_budget" {
  billing_account = var.billing_account_id
  display_name    = "Monthly Budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = "1000"  # $1000/month
    }
  }

  threshold_rules {
    threshold_percent = 0.5  # Alert at 50%
  }
  threshold_rules {
    threshold_percent = 0.8  # Alert at 80%
  }
  threshold_rules {
    threshold_percent = 1.0  # Alert at 100%
  }
}
```

### Cost Anomaly Detection
- Enable "Budget alerts" in Cloud Console
- Set up Pub/Sub notifications for budget alerts
- Use Cloud Monitoring for resource utilization metrics

---

## Cost Optimization Checklist

### Compute
- [ ] Use Cloud Run for stateless services (scale to zero)
- [ ] Use GKE Autopilot instead of Standard GKE
- [ ] Use E2 instances for general workloads
- [ ] Enable preemptible/spot VMs for fault-tolerant jobs
- [ ] Apply committed use discounts for predictable workloads
- [ ] Right-size instances (use recommender API)

### Storage
- [ ] Use lifecycle policies for Cloud Storage
- [ ] Partition and cluster BigQuery tables
- [ ] Delete old snapshots and unused disks
- [ ] Use appropriate storage class (Nearline/Coldline for archives)

### Database
- [ ] Right-size Cloud SQL instances
- [ ] Use read replicas instead of larger primary
- [ ] Enable query insights to optimize slow queries
- [ ] Schedule downtime for dev/staging databases

### Network
- [ ] Keep resources in same region
- [ ] Use Cloud CDN for static assets
- [ ] Use private IPs for internal communication
- [ ] Minimize cross-region traffic

### Monitoring
- [ ] Set up budget alerts
- [ ] Review Cost Reports monthly
- [ ] Use GCP Recommender for optimization suggestions
- [ ] Tag resources for cost attribution

---

## Tools

### GCP Native
- **Cloud Console > Billing > Cost Table**: Breakdown by service
- **Recommender**: AI-powered cost optimization suggestions
- **Pricing Calculator**: Estimate costs before deployment

### Third-Party
- **CloudHealth**: Multi-cloud cost management
- **Cloudability**: Cost analytics and optimization
- **Infracost**: Show cost estimates in pull requests (for Terraform)

---

## References

- [GCP Pricing](https://cloud.google.com/pricing)
- [GCP Pricing Calculator](https://cloud.google.com/products/calculator)
- [Cost Optimization Best Practices](https://cloud.google.com/architecture/cost-optimization)
- [Committed Use Discounts](https://cloud.google.com/compute/docs/instances/committed-use-discounts-overview)
