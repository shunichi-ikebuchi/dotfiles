# GCP Security & Compliance

Best practices for securing Google Cloud Platform infrastructure and meeting compliance requirements.

---

## Security Principles

### Defense in Depth
1. **Identity & Access Management (IAM)**: Least privilege access
2. **Network Security**: Private IPs, VPC Service Controls, firewall rules
3. **Data Protection**: Encryption at rest and in transit
4. **Monitoring & Logging**: Audit trails, anomaly detection
5. **Compliance**: Industry standards (HIPAA, PCI-DSS, SOC 2)

---

## Identity & Access Management (IAM)

### Least Privilege Principle
```hcl
# Good: Specific, minimal permissions
resource "google_project_iam_member" "cloud_run_sa" {
  project = var.project_id
  role    = "roles/cloudsql.client"  # Only what's needed
  member  = "serviceAccount:${google_service_account.api.email}"
}

# Bad: Overly broad permissions
resource "google_project_iam_member" "bad" {
  project = var.project_id
  role    = "roles/editor"  # ❌ Too much access
  member  = "serviceAccount:${google_service_account.api.email}"
}
```

### Service Accounts Best Practices
```hcl
# Good: Dedicated service account per service
resource "google_service_account" "api" {
  account_id   = "api-service"
  display_name = "API Service Account"
  project      = var.project_id
}

resource "google_service_account" "worker" {
  account_id   = "batch-worker"
  display_name = "Batch Worker Service Account"
  project      = var.project_id
}

# Grant specific permissions
resource "google_project_iam_member" "api_cloud_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api.email}"
}

resource "google_storage_bucket_iam_member" "api_bucket_viewer" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.api.email}"
}
```

### Workload Identity (GKE)
**Best practice**: Use Workload Identity instead of service account keys

```hcl
# Good: Workload Identity for GKE pods
resource "google_service_account" "k8s_app" {
  account_id = "k8s-app-sa"
  project    = var.project_id
}

# Bind Kubernetes SA to Google SA
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.k8s_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/k8s-app-sa]"
}

# Grant GCP permissions to service account
resource "google_project_iam_member" "k8s_app_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.k8s_app.email}"
}
```

```yaml
# Kubernetes Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k8s-app-sa
  annotations:
    iam.gke.io/gcp-service-account: k8s-app-sa@PROJECT_ID.iam.gserviceaccount.com
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      serviceAccountName: k8s-app-sa  # Use Workload Identity
      containers:
      - name: app
        image: gcr.io/project/app:v1
```

**Why Workload Identity?**
- ✅ No service account keys (keys are security risk)
- ✅ Automatic credential rotation
- ✅ Pod-level identity (not node-level)
- ✅ Audit trail (which pod accessed what)

### Avoid Service Account Keys
```bash
# ❌ Bad: Downloading service account keys
gcloud iam service-accounts keys create key.json \
  --iam-account=api@project.iam.gserviceaccount.com

# ✅ Good: Use Workload Identity (GKE) or default credentials (Cloud Run, Cloud Functions)
# No keys needed!
```

**If you MUST use keys**:
- Store in Secret Manager (never in code/environment variables)
- Rotate regularly (automate with Cloud Scheduler)
- Set expiration date
- Use service account key constraints

---

## Network Security

### VPC Design
```hcl
# Good: Private VPC with minimal public exposure
resource "google_compute_network" "vpc" {
  name                    = "private-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private" {
  name                     = "private-subnet"
  ip_cidr_range            = "10.0.0.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true  # Access Google APIs via private IP
}

# Firewall: Deny all ingress by default
resource "google_compute_firewall" "deny_all" {
  name    = "deny-all-ingress"
  network = google_compute_network.vpc.name

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  priority      = 65535  # Lowest priority (default deny)
}

# Firewall: Allow specific traffic
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["10.0.0.0/24"]  # Only from private subnet
  priority      = 1000
}
```

### VPC Service Controls
**Use case**: Prevent data exfiltration, enforce data perimeter

```hcl
# Define access policy
resource "google_access_context_manager_access_policy" "policy" {
  parent = "organizations/${var.org_id}"
  title  = "Data Perimeter Policy"
}

# Define service perimeter
resource "google_access_context_manager_service_perimeter" "perimeter" {
  parent = "accessPolicies/${google_access_context_manager_access_policy.policy.name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.policy.name}/servicePerimeters/data_perimeter"
  title  = "Data Perimeter"

  status {
    restricted_services = [
      "storage.googleapis.com",
      "bigquery.googleapis.com",
    ]

    resources = [
      "projects/${var.project_number}",
    ]

    # Only allow access from specific VPC
    vpc_accessible_services {
      enable_restriction = true
      allowed_services = [
        "storage.googleapis.com",
      ]
    }
  }
}
```

**Benefits**:
- ✅ Prevent data exfiltration (copy to external buckets)
- ✅ Enforce private connectivity
- ✅ Compliance requirements (HIPAA, PCI-DSS)

### Private GKE Cluster
```hcl
resource "google_container_cluster" "private" {
  name     = "private-cluster"
  location = var.region

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true  # Nodes have no public IPs
    enable_private_endpoint = false # Control plane has public endpoint (for kubectl)
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Master authorized networks (limit kubectl access)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "203.0.113.0/24"  # Office IP range
      display_name = "Office"
    }
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}
```

---

## Data Protection

### Encryption at Rest
**Default**: GCP encrypts all data at rest with Google-managed keys

**Customer-Managed Encryption Keys (CMEK)**:
```hcl
# Create Cloud KMS key
resource "google_kms_key_ring" "keyring" {
  name     = "app-keyring"
  location = "us-central1"
  project  = var.project_id
}

resource "google_kms_crypto_key" "key" {
  name     = "data-encryption-key"
  key_ring = google_kms_key_ring.keyring.id

  rotation_period = "7776000s"  # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

# Use CMEK for Cloud Storage
resource "google_storage_bucket" "encrypted" {
  name     = "encrypted-bucket"
  location = "US"

  encryption {
    default_kms_key_name = google_kms_crypto_key.key.id
  }
}

# Grant service account access to key
resource "google_kms_crypto_key_iam_member" "key_user" {
  crypto_key_id = google_kms_crypto_key.key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.api.email}"
}
```

**When to use CMEK**:
- ✅ Compliance requirements (HIPAA, PCI-DSS)
- ✅ Need key rotation control
- ✅ Need to revoke access by destroying key
- ❌ Not needed for most applications (Google-managed is sufficient)

### Encryption in Transit
```hcl
# Cloud Run: Always uses TLS
resource "google_cloud_run_service" "api" {
  name     = "api"
  location = var.region

  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "internal-and-cloud-load-balancing"  # Not public internet
    }
  }
}

# Cloud SQL: Enforce SSL
resource "google_sql_database_instance" "db" {
  name             = "db-instance"
  database_version = "POSTGRES_15"

  settings {
    ip_configuration {
      ipv4_enabled    = false  # No public IP
      private_network = google_compute_network.vpc.id
      require_ssl     = true   # Enforce SSL for connections
    }
  }
}
```

### Secret Management
```hcl
# Good: Store secrets in Secret Manager
resource "google_secret_manager_secret" "db_password" {
  secret_id = "db-password"
  project   = var.project_id

  replication {
    auto {}  # Automatic replication
  }

  # Rotation schedule
  rotation {
    next_rotation_time = "2024-06-01T00:00:00Z"
    rotation_period    = "2592000s"  # 30 days
  }
}

resource "google_secret_manager_secret_version" "db_password_v1" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password  # Injected from CI/CD, never committed
}

# Grant access to secret
resource "google_secret_manager_secret_iam_member" "api_access" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}
```

**Cloud Run usage**:
```yaml
spec:
  containers:
  - image: gcr.io/project/api:v1
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-password
          key: latest
```

---

## Monitoring & Logging

### Cloud Audit Logs
```hcl
# Enable audit logs for all services
resource "google_project_iam_audit_config" "audit" {
  project = var.project_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"  # Admin activity (who created/deleted resources)
  }

  audit_log_config {
    log_type = "DATA_READ"  # Data access (who read sensitive data)
  }

  audit_log_config {
    log_type = "DATA_WRITE"  # Data modification
  }
}
```

**Log Types**:
- **Admin Activity**: Always enabled, free (who created/deleted resources)
- **Data Access**: Must enable, costs money (who accessed data)
- **System Events**: Free (GCP-initiated events)

**Export logs for long-term retention**:
```hcl
resource "google_logging_project_sink" "audit_sink" {
  name        = "audit-log-sink"
  destination = "storage.googleapis.com/${google_storage_bucket.audit_logs.name}"

  filter = <<-EOT
    logName:"cloudaudit.googleapis.com"
    AND severity >= WARNING
  EOT

  unique_writer_identity = true
}

# Grant sink permission to write to bucket
resource "google_storage_bucket_iam_member" "log_writer" {
  bucket = google_storage_bucket.audit_logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.audit_sink.writer_identity
}
```

### Security Command Center
**Enterprise tier features**:
- ✅ Vulnerability scanning
- ✅ Threat detection
- ✅ Security Health Analytics
- ✅ Event Threat Detection

```bash
# Enable Security Command Center
gcloud services enable securitycenter.googleapis.com

# View findings
gcloud scc findings list ORGANIZATION_ID \
  --filter="state=\"ACTIVE\""
```

---

## Compliance

### HIPAA Compliance
**Requirements**:
1. Sign Business Associate Agreement (BAA) with Google
2. Use CMEK for PHI data
3. Enable audit logs (data access)
4. Encrypt in transit (TLS)
5. Access controls (IAM)
6. VPC Service Controls (data perimeter)

**Eligible GCP Services**:
- ✅ Compute Engine, GKE, Cloud Run
- ✅ Cloud Storage, Cloud SQL, BigQuery (with CMEK)
- ✅ Secret Manager, Cloud KMS
- ❌ App Engine Standard, Cloud Functions (not HIPAA-eligible)

### PCI-DSS Compliance
**Key Controls**:
1. Network segmentation (VPC, firewall rules)
2. Encryption (CMEK for cardholder data)
3. Access controls (IAM, least privilege)
4. Audit logging (Cloud Audit Logs)
5. Vulnerability management (Security Command Center)

**Attestation**:
- GCP provides PCI-DSS attestation of compliance (AOC)
- Download from Compliance Reports Manager

### SOC 2 Compliance
**GCP provides**:
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
- [ ] Use least privilege (specific roles, not Owner/Editor)
- [ ] Dedicated service account per service
- [ ] Enable Workload Identity for GKE
- [ ] No service account keys (use Workload Identity)
- [ ] Regular IAM audit (remove unused accounts)

### Network
- [ ] Private subnets (no public IPs)
- [ ] VPC Service Controls (for sensitive data)
- [ ] Firewall rules (deny by default)
- [ ] Private GKE cluster
- [ ] Cloud Armor (DDoS protection for public services)

### Data Protection
- [ ] Encryption in transit (TLS everywhere)
- [ ] CMEK for sensitive data (HIPAA, PCI-DSS)
- [ ] Secrets in Secret Manager (not env vars)
- [ ] Backup and disaster recovery plan
- [ ] Data lifecycle policies (auto-delete old data)

### Monitoring
- [ ] Cloud Audit Logs enabled
- [ ] Log export to Cloud Storage (long-term retention)
- [ ] Budget alerts (detect crypto mining)
- [ ] Security Command Center (if Enterprise)
- [ ] Monitoring dashboards and alerts

### Compliance
- [ ] Sign BAA for HIPAA
- [ ] Download PCI-DSS AOC
- [ ] Download SOC 2 reports
- [ ] Regular security audits
- [ ] Incident response plan

---

## Tools

### GCP Native
- **Security Command Center**: Threat detection, vulnerability scanning
- **Cloud Armor**: DDoS protection, WAF
- **Cloud KMS**: Key management
- **Secret Manager**: Secrets storage
- **VPC Service Controls**: Data perimeter
- **Binary Authorization**: Container image signing (GKE)

### Third-Party
- **Wiz**: Cloud security posture management
- **Lacework**: Cloud workload protection
- **Snyk**: Container vulnerability scanning
- **Falco**: Runtime security for Kubernetes

---

## References

- [GCP Security Best Practices](https://cloud.google.com/security/best-practices)
- [GCP Security Command Center](https://cloud.google.com/security-command-center)
- [HIPAA on GCP](https://cloud.google.com/security/compliance/hipaa)
- [PCI-DSS on GCP](https://cloud.google.com/security/compliance/pci-dss)
- [VPC Service Controls](https://cloud.google.com/vpc-service-controls/docs)
