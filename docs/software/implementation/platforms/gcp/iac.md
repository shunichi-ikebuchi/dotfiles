# GCP Infrastructure as Code (IaC)

Best practices for managing GCP infrastructure using code for reproducibility, version control, and automation.

---

## Tool Selection

### Terraform (Recommended)
**Best for**: Multi-cloud, mature ecosystem, portable

**Pros**:
- ✅ Multi-cloud support (GCP, AWS, Azure)
- ✅ Large community, extensive modules
- ✅ State management and drift detection
- ✅ Plan before apply (preview changes)

**Cons**:
- ❌ HCL learning curve
- ❌ State file management complexity

### Pulumi
**Best for**: Developers preferring general-purpose languages

**Pros**:
- ✅ Use TypeScript, Python, Go, C#
- ✅ Strong typing and IDE support
- ✅ Unit testing infrastructure code
- ✅ Multi-cloud support

**Cons**:
- ❌ Smaller community than Terraform
- ❌ State management (similar to Terraform)

### Deployment Manager (GCP Native)
**Best for**: Simple GCP-only projects

**Pros**:
- ✅ Native GCP integration
- ✅ No state file management
- ✅ Python or Jinja2 templates

**Cons**:
- ❌ GCP lock-in (not portable)
- ❌ Limited community resources
- ❌ Less mature than Terraform

**Recommendation**: Use **Terraform** for most projects (portability). Use **Pulumi** if team prefers programming languages. Avoid Deployment Manager unless GCP-only is acceptable.

---

## Terraform Best Practices

### Project Structure
```
infrastructure/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   └── prod/
├── modules/
│   ├── gke-cluster/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cloud-run-service/
│   └── vpc-network/
└── shared/
    ├── providers.tf
    └── versions.tf
```

### State Management
```hcl
# Good: Remote state in Cloud Storage
terraform {
  backend "gcs" {
    bucket = "my-company-terraform-state"
    prefix = "prod/vpc"
  }

  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

**Best Practices**:
- ✅ Use separate state files per environment
- ✅ Enable versioning on state bucket
- ✅ Encrypt state bucket (customer-managed keys)
- ✅ Lock state during operations (default with GCS backend)
- ❌ Never commit state files to Git

### Variables and Outputs
```hcl
# variables.tf - Input variables
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# outputs.tf - Exported values
output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "service_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_service.api.status[0].url
}
```

### Resource Naming Conventions
```hcl
# Good: Consistent naming with environment and purpose
resource "google_compute_network" "vpc" {
  name                    = "${var.environment}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "private" {
  name          = "${var.environment}-${var.region}-private-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/20"
  }
}
```

### Modules for Reusability
```hcl
# modules/gke-cluster/main.tf
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Enable Autopilot (managed nodes)
  enable_autopilot = true

  # Workload Identity for secure pod authentication
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Private cluster (no public IPs)
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }
}

# environments/prod/main.tf - Using the module
module "gke_cluster" {
  source = "../../modules/gke-cluster"

  cluster_name = "prod-cluster"
  project_id   = var.project_id
  region       = var.region
}
```

---

## Cloud Run with Terraform

```hcl
resource "google_cloud_run_service" "api" {
  name     = "${var.environment}-api"
  location = var.region
  project  = var.project_id

  template {
    spec {
      service_account_name = google_service_account.api.email

      containers {
        image = "gcr.io/${var.project_id}/api:${var.image_tag}"

        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }

        env {
          name  = "DATABASE_URL"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.db_url.secret_id
              key  = "latest"
            }
          }
        }

        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = var.environment == "prod" ? "2" : "0"
        "autoscaling.knative.dev/maxScale" = var.environment == "prod" ? "100" : "10"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# IAM binding for public access (if needed)
resource "google_cloud_run_service_iam_member" "public_access" {
  count = var.allow_public_access ? 1 : 0

  service  = google_cloud_run_service.api.name
  location = google_cloud_run_service.api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
```

---

## Secrets Management

```hcl
# Good: Secret Manager
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.environment}-db-password"
  project   = var.project_id

  replication {
    auto {}  # Replicate across multiple regions
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret = google_secret_manager_secret.db_password.id

  # Never hardcode secrets! Use external data source or manual creation
  secret_data = var.db_password  # Injected via CI/CD or tfvars (encrypted)
}

# Grant Cloud Run service access to secret
resource "google_secret_manager_secret_iam_member" "api_access" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}
```

**Best Practices**:
- ❌ Never commit secrets to Git (use `.gitignore` for `*.tfvars`)
- ✅ Use Secret Manager for runtime secrets
- ✅ Use environment variables in CI/CD for Terraform secrets
- ✅ Enable secret rotation policies
- ✅ Audit secret access with Cloud Logging

---

## Service Accounts & IAM

```hcl
# Good: Least privilege service account
resource "google_service_account" "api" {
  account_id   = "${var.environment}-api-sa"
  display_name = "${var.environment} API Service Account"
  project      = var.project_id
}

# Grant specific permissions
resource "google_project_iam_member" "api_cloud_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api.email}"
}

resource "google_project_iam_member" "api_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.api.email}"
}

# Bad: Too broad
resource "google_project_iam_member" "bad_example" {
  project = var.project_id
  role    = "roles/editor"  # ❌ Too much access
  member  = "serviceAccount:${google_service_account.api.email}"
}
```

---

## Pulumi Example (TypeScript)

```typescript
// index.ts
import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();
const projectId = config.require("projectId");
const region = config.get("region") || "us-central1";

// VPC Network
const network = new gcp.compute.Network("vpc", {
  autoCreateSubnetworks: false,
  project: projectId,
});

const subnet = new gcp.compute.Subnetwork("private-subnet", {
  ipCidrRange: "10.0.0.0/24",
  region: region,
  network: network.id,
  project: projectId,
  secondaryIpRanges: [
    { rangeName: "pods", ipCidrRange: "10.1.0.0/16" },
    { rangeName: "services", ipCidrRange: "10.2.0.0/20" },
  ],
});

// Cloud Run Service
const serviceAccount = new gcp.serviceaccount.Account("api-sa", {
  accountId: `${pulumi.getStack()}-api-sa`,
  displayName: "API Service Account",
  project: projectId,
});

const service = new gcp.cloudrun.Service("api", {
  location: region,
  project: projectId,
  template: {
    spec: {
      serviceAccountName: serviceAccount.email,
      containers: [{
        image: `gcr.io/${projectId}/api:latest`,
        resources: {
          limits: { cpu: "1000m", memory: "512Mi" },
        },
        envs: [{
          name: "ENVIRONMENT",
          value: pulumi.getStack(),
        }],
      }],
    },
  },
});

// Exports
export const serviceUrl = service.statuses[0].url;
export const vpcId = network.id;
```

**Pulumi Benefits**:
- ✅ Full programming language (TypeScript/Python/Go)
- ✅ Type safety and autocomplete
- ✅ Unit testing infrastructure code
- ✅ Reuse existing libraries

---

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Terraform Apply

on:
  push:
    branches: [main]
    paths:
      - 'infrastructure/**'

env:
  TF_VERSION: '1.5.0'
  GCP_PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: infrastructure/environments/prod

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve tfplan
```

---

## Testing Infrastructure Code

### Terratest (Go)
```go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestGKECluster(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/gke-cluster",
        Vars: map[string]interface{}{
            "cluster_name": "test-cluster",
            "project_id":   "test-project",
            "region":       "us-central1",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    clusterName := terraform.Output(t, terraformOptions, "cluster_name")
    assert.Equal(t, "test-cluster", clusterName)
}
```

---

## References

- [Terraform GCP Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Pulumi GCP Guide](https://www.pulumi.com/docs/clouds/gcp/)
- [GCP Terraform Best Practices](https://cloud.google.com/docs/terraform/best-practices-for-terraform)
- [Terratest](https://terratest.gruntwork.io/)
