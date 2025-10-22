# Amazon Web Services (AWS) Guidelines

AWS-specific instructions for AI coding agents working on cloud infrastructure.

**Philosophy**: Leverage AWS's ecosystem breadth while avoiding excessive vendor lock-in through portable patterns and abstractions.

---

## Quick Reference

### Core Principles
- ✅ Use managed services for operational simplicity
- ✅ Prefer portable abstractions (Kubernetes, Terraform) over proprietary ones
- ✅ Leverage AWS's strengths: Lambda, RDS, S3, DynamoDB
- ✅ Design for multi-cloud compatibility when feasible
- ✅ Infrastructure as Code for all resources
- ❌ Avoid proprietary services when portable alternatives exist
- ❌ Avoid manual console configurations (use IaC)

### Architecture Patterns
- ✅ Serverless-first: Lambda, API Gateway, Fargate
- ✅ Containerization: EKS (Kubernetes) for portability
- ✅ Event-driven: EventBridge, SQS, SNS for async messaging
- ✅ Data lakes: S3 + Athena/Redshift
- ❌ Avoid tight coupling to AWS-specific APIs

### Security & Compliance
- ✅ IAM roles (no access keys) with least privilege
- ✅ IRSA (IAM Roles for Service Accounts) for EKS
- ✅ VPC security groups and NACLs
- ✅ KMS customer-managed keys for sensitive data
- ✅ CloudTrail for audit logs

### Cost Optimization
- ✅ Savings Plans and Reserved Instances for predictable workloads
- ✅ Spot Instances for batch processing (up to 90% savings)
- ✅ S3 Intelligent-Tiering and lifecycle policies
- ✅ Lambda reserved concurrency and Provisioned Concurrency
- ✅ Cost allocation tags and budgets

---

## Detailed Guidelines

For comprehensive AWS best practices, see:
- **[Architecture Patterns](./architecture.md)**: Serverless, microservices, data pipelines
- **[Infrastructure as Code](./iac.md)**: Terraform, CDK best practices
- **[Cost Optimization](./cost-optimization.md)**: Resource management, billing
- **[Security & Compliance](./security.md)**: IAM, encryption, audit

---

## AWS Service Selection Guide

### Compute
| Use Case | AWS Service | Portability | Notes |
|----------|-------------|-------------|-------|
| **Serverless functions** | Lambda | ⭐⭐ Medium | Use container images for portability |
| **Stateless containers** | Fargate (ECS/EKS) | ⭐⭐⭐ High | Standard containers, portable |
| **Kubernetes** | EKS | ⭐⭐⭐ High | Standard K8s, multi-cloud ready |
| **Batch jobs** | Batch | ⭐⭐ Medium | Use containers for portability |
| **VMs** | EC2 | ⭐⭐ Medium | Standard VMs, IaC makes it portable |

### Storage
| Use Case | AWS Service | Portability | Notes |
|----------|-------------|-------------|-------|
| **Object storage** | S3 | ⭐⭐⭐ High | Industry standard API |
| **Relational DB** | RDS (PostgreSQL/MySQL) | ⭐⭐⭐ High | Standard databases |
| **NoSQL (key-value)** | DynamoDB | ⭐ Low | Consider MongoDB Atlas for portability |
| **NoSQL (document)** | DocumentDB (MongoDB) | ⭐⭐ Medium | MongoDB-compatible |
| **Data warehouse** | Redshift | ⭐⭐ Medium | Use standard SQL for portability |
| **In-memory cache** | ElastiCache (Redis) | ⭐⭐⭐ High | Standard Redis protocol |

### Messaging & Events
| Use Case | AWS Service | Portability | Notes |
|----------|-------------|-------------|-------|
| **Event bus** | EventBridge | ⭐ Low | Use abstraction layer |
| **Message queues** | SQS | ⭐⭐ Medium | Simple Queue, use abstraction |
| **Pub/Sub** | SNS | ⭐⭐ Medium | Use abstraction layer |
| **Streaming** | Kinesis | ⭐ Low | Consider Apache Kafka for portability |

### Monitoring & Logging
| Use Case | AWS Service | Portability | Notes |
|----------|-------------|-------------|-------|
| **Logging** | CloudWatch Logs | ⭐⭐ Medium | Export to OpenTelemetry for portability |
| **Monitoring** | CloudWatch | ⭐⭐ Medium | Use Prometheus + Grafana for portability |
| **Tracing** | X-Ray | ⭐⭐ Medium | OpenTelemetry compatible |

---

## Balancing AWS Strengths & Portability

### Leverage These AWS Strengths
1. **Lambda**: Mature serverless compute with extensive integrations
2. **S3**: Industry-standard object storage
3. **RDS**: Fully managed relational databases
4. **DynamoDB**: Highly scalable NoSQL with single-digit millisecond latency
5. **EKS**: Managed Kubernetes with AWS integrations

### Use Abstraction Layers For
1. **Message queues**: Wrap SQS/SNS behind your own interface
2. **Event buses**: Abstract EventBridge
3. **Secrets**: Abstract Secrets Manager behind interface
4. **Monitoring**: Export to OpenTelemetry

### Example: Portable Message Queue
```typescript
// Good: Abstraction layer for portability
interface MessageQueue {
  publish(topic: string, message: any): Promise<void>;
  subscribe(topic: string, handler: (msg: any) => Promise<void>): Promise<void>;
}

// AWS SQS implementation
class SQSQueue implements MessageQueue {
  constructor(private sqsClient: SQSClient) {}

  async publish(queueUrl: string, message: any): Promise<void> {
    await this.sqsClient.send(new SendMessageCommand({
      QueueUrl: queueUrl,
      MessageBody: JSON.stringify(message),
    }));
  }

  // Can swap for GCP Pub/Sub or Apache Kafka later
}
```

---

## Common Anti-Patterns

### ❌ Direct Service Dependencies
```python
# Bad: Direct dependency on DynamoDB
import boto3

def get_user(user_id):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('users')
    return table.get_item(Key={'id': user_id})
```

### ✅ Abstraction Layer
```python
# Good: Repository pattern
from abc import ABC, abstractmethod

class UserRepository(ABC):
    @abstractmethod
    def get_user(self, user_id: str) -> Optional[User]:
        pass

class DynamoDBUserRepository(UserRepository):
    def __init__(self, table_name: str):
        self.dynamodb = boto3.resource('dynamodb')
        self.table = self.dynamodb.Table(table_name)

    def get_user(self, user_id: str) -> Optional[User]:
        response = self.table.get_item(Key={'id': user_id})
        item = response.get('Item')
        return User.from_dict(item) if item else None
```

---

## Integration with General Principles

AWS infrastructure should follow:
- **[Unix Philosophy](../../../design/practices/unix-philosophy.md)**: Single responsibility, composability
- **[Code Quality](../../general/code-quality.md)**: Explicitness, fail-fast (for IaC)
- **[Testing Strategy](../../../../testing/strategy.md)**: Automated testing for infrastructure

---

## When to Escalate

Consult human developers for:
- **Multi-region architecture**: Data residency, latency trade-offs
- **Major cost commitments**: Savings Plans, Reserved Instances
- **Security compliance**: HIPAA, PCI-DSS, SOC 2 requirements
- **Vendor lock-in decisions**: When to embrace vs. avoid AWS-specific services
- **Data migration**: Moving large datasets between regions/clouds
- **Serverless vs. containers**: Lambda vs. Fargate/EKS trade-offs
