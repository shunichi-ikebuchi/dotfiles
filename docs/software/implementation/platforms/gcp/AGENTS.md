# Google Cloud Platform (GCP) Guidelines

GCP-specific instructions for AI coding agents working on cloud infrastructure.

**Philosophy**: Leverage GCP's unique strengths while avoiding excessive vendor lock-in through portable patterns and abstractions.

---

## Quick Reference

### Core Principles
- ✅ Use managed services for operational simplicity
- ✅ Prefer portable abstractions (Kubernetes, Terraform) over proprietary ones
- ✅ Leverage GCP's strengths: BigQuery, Pub/Sub, Cloud Run
- ✅ Design for multi-cloud compatibility when feasible
- ✅ Infrastructure as Code for all resources
- ❌ Avoid proprietary services when portable alternatives exist
- ❌ Avoid manual console configurations (use IaC)

### Architecture Patterns
- ✅ Serverless-first: Cloud Run, Cloud Functions
- ✅ Containerization: GKE (Kubernetes) for portability
- ✅ Event-driven: Pub/Sub for async messaging
- ✅ Data lakes: Cloud Storage + BigQuery
- ❌ Avoid tight coupling to GCP-specific APIs

### Security & Compliance
- ✅ Workload Identity for GKE (no service account keys)
- ✅ IAM least privilege (granular permissions)
- ✅ VPC Service Controls for data perimeter
- ✅ Customer-managed encryption keys (CMEK) for sensitive data
- ✅ Cloud Audit Logs for compliance

### Cost Optimization
- ✅ Committed use discounts for predictable workloads
- ✅ Preemptible VMs for batch processing
- ✅ Cloud Storage lifecycle policies
- ✅ BigQuery partitioning and clustering
- ✅ Budget alerts and quotas

---

## Detailed Guidelines

For comprehensive GCP best practices, see:
- **[Architecture Patterns](./architecture.md)**: Serverless, microservices, data pipelines
- **[Infrastructure as Code](./iac.md)**: Terraform, Pulumi best practices
- **[Cost Optimization](./cost-optimization.md)**: Resource management, billing
- **[Security & Compliance](./security.md)**: IAM, encryption, audit

---

## GCP Service Selection Guide

### Compute
| Use Case | GCP Service | Portability | Notes |
|----------|-------------|-------------|-------|
| **Stateless containers** | Cloud Run | ⭐⭐⭐ High | Standard containers, portable |
| **Kubernetes** | GKE (Autopilot) | ⭐⭐⭐ High | Standard K8s, multi-cloud ready |
| **Batch jobs** | Cloud Batch | ⭐⭐ Medium | Use container-based for portability |
| **Functions** | Cloud Functions | ⭐ Low | Use Cloud Run instead for portability |
| **VMs** | Compute Engine | ⭐⭐ Medium | Standard VMs, IaC makes it portable |

### Storage
| Use Case | GCP Service | Portability | Notes |
|----------|-------------|-------------|-------|
| **Object storage** | Cloud Storage | ⭐⭐⭐ High | S3-compatible API available |
| **Relational DB** | Cloud SQL (PostgreSQL) | ⭐⭐⭐ High | Standard PostgreSQL/MySQL |
| **NoSQL** | Firestore | ⭐ Low | Consider MongoDB Atlas for portability |
| **Data warehouse** | BigQuery | ⭐⭐ Medium | Unique strength, hard to replace |

### Messaging & Events
| Use Case | GCP Service | Portability | Notes |
|----------|-------------|-------------|-------|
| **Pub/Sub messaging** | Pub/Sub | ⭐⭐ Medium | Strong GCP feature, use abstraction layer |
| **Task queues** | Cloud Tasks | ⭐ Low | Consider portable alternatives (Redis Queue) |

### Monitoring & Logging
| Use Case | GCP Service | Portability | Notes |
|----------|-------------|-------------|-------|
| **Logging** | Cloud Logging | ⭐⭐ Medium | Export to OpenTelemetry for portability |
| **Monitoring** | Cloud Monitoring | ⭐⭐ Medium | Use Prometheus + Grafana for portability |
| **Tracing** | Cloud Trace | ⭐⭐ Medium | OpenTelemetry compatible |

---

## Balancing GCP Strengths & Portability

### Leverage These GCP Strengths
1. **BigQuery**: Unmatched serverless data warehouse performance
2. **Pub/Sub**: Reliable, scalable event streaming
3. **Cloud Run**: Simplest container deployment
4. **GKE Autopilot**: Fully managed Kubernetes

### Use Abstraction Layers For
1. **Message queues**: Wrap Pub/Sub behind your own interface
2. **Object storage**: Use S3-compatible API or abstraction library
3. **Secrets**: Abstract Secret Manager behind interface
4. **Monitoring**: Export to OpenTelemetry

### Example: Portable Message Queue
```go
// Good: Abstraction layer for portability
type MessageQueue interface {
    Publish(ctx context.Context, topic string, msg []byte) error
    Subscribe(ctx context.Context, subscription string) (<-chan Message, error)
}

// GCP implementation
type PubSubQueue struct {
    client *pubsub.Client
}

// Can swap for AWS SQS/SNS or Kafka later
```

---

## Common Anti-Patterns

### ❌ Direct Service Dependencies
```python
# Bad: Direct dependency on Firestore
from google.cloud import firestore

def get_user(user_id):
    db = firestore.Client()
    return db.collection('users').document(user_id).get()
```

### ✅ Abstraction Layer
```python
# Good: Repository pattern
class UserRepository(ABC):
    @abstractmethod
    def get_user(self, user_id: str) -> Optional[User]:
        pass

class FirestoreUserRepository(UserRepository):
    def __init__(self, client: firestore.Client):
        self._client = client

    def get_user(self, user_id: str) -> Optional[User]:
        doc = self._client.collection('users').document(user_id).get()
        return User.from_dict(doc.to_dict()) if doc.exists else None
```

---

## Integration with General Principles

GCP infrastructure should follow:
- **[Unix Philosophy](../../../design/practices/unix-philosophy.md)**: Single responsibility, composability
- **[Code Quality](../../general/code-quality.md)**: Explicitness, fail-fast (for IaC)
- **[Testing Strategy](../../../../testing/strategy.md)**: Automated testing for infrastructure

---

## When to Escalate

Consult human developers for:
- **Multi-region architecture**: Data residency, latency trade-offs
- **Major cost commitments**: Committed use discounts, reservations
- **Security compliance**: HIPAA, PCI-DSS, SOC 2 requirements
- **Vendor lock-in decisions**: When to embrace vs. avoid GCP-specific services
- **Data migration**: Moving large datasets between regions/clouds
