# AWS Architecture Patterns

Best practices for designing scalable, resilient, and portable architectures on Amazon Web Services.

---

## Serverless Architecture

### Lambda - Event-Driven Functions
**Best for**: Event processing, API backends, scheduled tasks

```typescript
// Good: Portable Lambda handler (container image)
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const body = JSON.parse(event.body || '{}');

    // Business logic (portable)
    const result = await processRequest(body);

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(result),
    };
  } catch (error) {
    console.error('Error processing request', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};
```

**Lambda Best Practices**:
- ✅ Use container images for portability (same code works on Fargate/EKS)
- ✅ Externalize configuration (env vars, SSM Parameter Store)
- ✅ Use Lambda Layers for shared dependencies
- ✅ Set appropriate timeout and memory (right-size for cost)
- ✅ Enable X-Ray tracing for debugging
- ❌ Avoid Lambda monoliths (keep functions focused)
- ❌ Avoid storing state in /tmp (ephemeral)

**Lambda Limits**:
- 15-minute max execution time
- 10 GB memory max
- 512 MB /tmp storage
- 6 MB request/response size (synchronous)

**When to use Lambda**:
- Event-driven workloads (S3, DynamoDB Streams, EventBridge)
- Sporadic traffic (scale to zero)
- Short-lived tasks (<15 min)

**When to use Fargate instead**:
- Long-running processes (>15 min)
- Larger memory requirements (>10 GB)
- Need persistent storage

### API Gateway + Lambda
```yaml
# SAM template (portable to OpenAPI)
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Resources:
  ApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: ./src
      Handler: index.handler
      Runtime: nodejs20.x
      Architectures: [arm64]  # Graviton2 (cheaper)
      MemorySize: 512
      Timeout: 30
      Environment:
        Variables:
          TABLE_NAME: !Ref UsersTable
      Events:
        GetUser:
          Type: Api
          Properties:
            Path: /users/{id}
            Method: GET
            RestApiId: !Ref ApiGateway

  ApiGateway:
    Type: AWS::Serverless::Api
    Properties:
      StageName: prod
      Auth:
        DefaultAuthorizer: AWS_IAM  # Or Lambda authorizer, Cognito
```

---

## Container-Based Architecture

### ECS Fargate - Serverless Containers
**Best for**: Microservices, stateless web apps

```json
// ECS Task Definition (portable container)
{
  "family": "api-service",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "123456789.dkr.ecr.us-east-1.amazonaws.com/api:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "ENVIRONMENT",
          "value": "production"
        }
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789:secret:db-password"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/api-service",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "api"
        }
      }
    }
  ]
}
```

**Fargate vs. EC2 Launch Type**:
| Feature | Fargate | EC2 |
|---------|---------|-----|
| **Management** | Serverless (no servers) | Manage EC2 instances |
| **Pricing** | Per vCPU/GB-hour | Per EC2 instance |
| **Scaling** | Task-level | Instance + task-level |
| **Cost** | More expensive per task | Cheaper at scale |
| **Best for** | Variable workloads | Steady-state workloads |

### EKS - Managed Kubernetes
**Best for**: Multi-cloud portability, complex orchestration

```yaml
# Standard Kubernetes Deployment (portable)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      serviceAccountName: user-service-sa
      containers:
      - name: user-service
        image: 123456789.dkr.ecr.us-east-1.amazonaws.com/user-service:v1
        ports:
        - containerPort: 8080
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: db-config
              key: host
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
spec:
  type: LoadBalancer
  selector:
    app: user-service
  ports:
  - port: 80
    targetPort: 8080
```

**EKS Best Practices**:
- ✅ Use Fargate for serverless pods (no node management)
- ✅ Use managed node groups for EC2-backed pods
- ✅ Enable IRSA (IAM Roles for Service Accounts)
- ✅ Use AWS Load Balancer Controller
- ✅ Enable cluster autoscaler
- ✅ Use Graviton3 instances (better price/performance)

---

## Event-Driven Architecture

### EventBridge - Event Bus
**Pattern**: Decouple services with events

```typescript
// Good: Publish events to EventBridge
import { EventBridgeClient, PutEventsCommand } from '@aws-sdk/client-eventbridge';

interface OrderCreatedEvent {
  orderId: string;
  userId: string;
  amount: number;
}

async function publishOrderCreated(event: OrderCreatedEvent): Promise<void> {
  const client = new EventBridgeClient({});

  await client.send(new PutEventsCommand({
    Entries: [{
      Source: 'order-service',
      DetailType: 'OrderCreated',
      Detail: JSON.stringify(event),
      EventBusName: 'default',
    }],
  }));
}
```

```yaml
# EventBridge Rule (subscribe to events)
Resources:
  OrderCreatedRule:
    Type: AWS::Events::Rule
    Properties:
      EventBusName: default
      EventPattern:
        source:
          - order-service
        detail-type:
          - OrderCreated
      Targets:
        - Arn: !GetAtt PaymentFunction.Arn
          Id: PaymentTarget
        - Arn: !GetAtt InventoryFunction.Arn
          Id: InventoryTarget
```

**EventBridge Benefits**:
- ✅ Decoupled architecture (services don't know consumers)
- ✅ Schema registry (document event structure)
- ✅ Event replay (reprocess events)
- ✅ 100+ SaaS integrations (Stripe, Shopify, etc.)

### SQS - Message Queues
**Pattern**: Async processing, job queues

```typescript
// Good: Send message to SQS
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';

async function enqueueJob(queueUrl: string, job: any): Promise<void> {
  const client = new SQSClient({});

  await client.send(new SendMessageCommand({
    QueueUrl: queueUrl,
    MessageBody: JSON.stringify(job),
    MessageAttributes: {
      jobType: {
        DataType: 'String',
        StringValue: job.type,
      },
    },
  }));
}

// Lambda consumer
export const handler = async (event: SQSEvent): Promise<void> => {
  for (const record of event.Records) {
    const job = JSON.parse(record.body);
    await processJob(job);
  }
};
```

**SQS Best Practices**:
- ✅ Use FIFO queues for ordering (suffix: `.fifo`)
- ✅ Set appropriate visibility timeout
- ✅ Use dead-letter queues for failed messages
- ✅ Batch operations (up to 10 messages)
- ❌ Avoid polling in Lambda (use event source mapping)

---

## Data Pipeline Architecture

### S3 + Athena + Glue
**Pattern**: Data lake and serverless analytics

```
S3 Data Lake
    ├── raw/          # Raw ingested data (JSON, CSV, Parquet)
    ├── processed/    # Cleaned, transformed data
    └── analytics/    # Aggregated, business-ready data

AWS Glue Catalog
    ├── raw_database
    ├── processed_database
    └── analytics_database

Amazon Athena (query with SQL)
```

**Glue ETL Job** (Spark):
```python
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Read from S3 (via Glue Catalog)
datasource = glueContext.create_dynamic_frame.from_catalog(
    database="raw_database",
    table_name="user_events"
)

# Transform
transformed = datasource.filter(lambda x: x["event_type"] == "purchase")

# Write to S3 (Parquet format)
glueContext.write_dynamic_frame.from_options(
    frame=transformed,
    connection_type="s3",
    connection_options={"path": "s3://my-bucket/processed/purchases/"},
    format="parquet"
)

job.commit()
```

**Athena Query**:
```sql
-- Serverless SQL queries on S3 data
SELECT
  user_id,
  COUNT(*) as purchase_count,
  SUM(amount) as total_spent
FROM analytics.purchases
WHERE year = 2024 AND month = 1
GROUP BY user_id
ORDER BY total_spent DESC
LIMIT 100;
```

---

## Resilience Patterns

### Circuit Breaker
```typescript
import CircuitBreaker from 'opossum';

// Good: Circuit breaker for external APIs
const breaker = new CircuitBreaker(callExternalAPI, {
  timeout: 3000,        // 3 seconds
  errorThresholdPercentage: 50,
  resetTimeout: 30000,  // 30 seconds
});

breaker.fallback(() => ({ error: 'Service unavailable' }));

breaker.on('open', () => {
  console.error('Circuit breaker opened - service is failing');
});

async function callExternalAPI(data: any): Promise<any> {
  const response = await fetch('https://api.example.com/data', {
    method: 'POST',
    body: JSON.stringify(data),
  });
  return response.json();
}

// Use circuit breaker
const result = await breaker.fire({ userId: '123' });
```

### Retry with Exponential Backoff
```typescript
import pRetry from 'p-retry';

// Good: Retry with exponential backoff
async function fetchDataWithRetry(url: string): Promise<any> {
  return pRetry(
    async () => {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      return response.json();
    },
    {
      retries: 5,
      factor: 2,           // Exponential backoff
      minTimeout: 1000,    // 1 second
      maxTimeout: 30000,   // 30 seconds
    }
  );
}
```

---

## Multi-Region Architecture

### Active-Active (Global)
```
Region: us-east-1          Region: eu-west-1
├── EKS Cluster           ├── EKS Cluster
├── RDS (primary)         ├── RDS (read replica)
├── S3 (replication →)    ├── S3 (← replicated)
└── CloudFront (global CDN)

Route 53 (global DNS with health checks)
- Geolocation routing: Route users to nearest region
- Failover routing: Automatic failover if region is down
```

### Active-Passive (DR)
```
Primary: us-east-1         DR: us-west-2
├── EKS Cluster (active)  ├── EKS Cluster (standby)
├── RDS (primary)         ├── RDS (standby, auto-failover)
└── S3 (replication →)    └── S3 (← replicated)

Route 53 Failover:
- Primary: us-east-1 (health check)
- Secondary: us-west-2 (failover)
```

---

## References

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Serverless Application Lens](https://docs.aws.amazon.com/wellarchitected/latest/serverless-applications-lens/welcome.html)
