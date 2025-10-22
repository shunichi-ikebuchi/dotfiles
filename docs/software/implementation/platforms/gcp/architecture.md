# GCP Architecture Patterns

Best practices for designing scalable, resilient, and portable architectures on Google Cloud Platform.

---

## Serverless Architecture

### Cloud Run - Stateless Containers
**Best for**: Web APIs, microservices, background workers

```yaml
# Good: Cloud Run service (portable container)
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: api-service
spec:
  template:
    spec:
      containers:
      - image: gcr.io/project/api:v1
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: url
        resources:
          limits:
            memory: 512Mi
            cpu: 1000m
```

**Key Features**:
- ✅ Auto-scaling from 0 to N instances
- ✅ Pay only for actual usage (100ms granularity)
- ✅ Standard containers (portable to any Kubernetes)
- ✅ Built-in TLS, IAM authentication
- ❌ Limited to 60-minute request timeout
- ❌ No persistent local storage

### Cloud Functions vs. Cloud Run
```
Use Cloud Run when:
- Need standard containers (portability)
- Need longer execution time (up to 60 min)
- Want to share code with non-serverless environments

Use Cloud Functions when:
- Very simple event handlers
- GCP event sources (Pub/Sub, Storage, Firestore triggers)
- Don't need portability
```

---

## Microservices Architecture

### GKE Autopilot - Managed Kubernetes
**Best for**: Complex microservices, multi-cloud portability

```yaml
# Good: Standard Kubernetes deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
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
        image: gcr.io/project/user-service:v1
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
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

**Autopilot Benefits**:
- ✅ Google manages nodes, networking, security
- ✅ Standard Kubernetes (portable)
- ✅ Pay per pod resource requests (no node management)
- ✅ Automatic scaling and upgrades

**When to use Standard GKE instead**:
- Need specific node configurations (GPUs, local SSD)
- Need Windows containers
- Need privileged containers

---

## Event-Driven Architecture

### Pub/Sub for Async Communication
**Pattern**: Event sourcing, async processing, decoupling services

```go
// Good: Abstracted message broker
type EventBus interface {
    Publish(ctx context.Context, topic string, event Event) error
    Subscribe(ctx context.Context, subscription string, handler EventHandler) error
}

// GCP Pub/Sub implementation
type PubSubEventBus struct {
    client *pubsub.Client
}

func (bus *PubSubEventBus) Publish(ctx context.Context, topic string, event Event) error {
    t := bus.client.Topic(topic)
    defer t.Stop()

    data, err := json.Marshal(event)
    if err != nil {
        return fmt.Errorf("marshal event: %w", err)
    }

    result := t.Publish(ctx, &pubsub.Message{
        Data: data,
        Attributes: map[string]string{
            "eventType": event.Type,
            "eventID":   event.ID,
        },
    })

    _, err = result.Get(ctx)
    return err
}
```

**Pub/Sub Best Practices**:
- ✅ Use message ordering when needed (ordering key)
- ✅ Set appropriate acknowledgment deadlines
- ✅ Handle duplicate messages (idempotent handlers)
- ✅ Use dead-letter topics for failed messages
- ✅ Monitor subscription backlog

### Example: Order Processing
```
                    ┌──────────────┐
                    │   API Gateway│
                    └──────┬───────┘
                           │
                    ┌──────▼────────┐
                    │ Order Service │
                    └──────┬────────┘
                           │ publish
                    ┌──────▼───────────┐
                    │  Pub/Sub: orders │
                    └──────┬───────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
    ┌─────────▼──┐  ┌──────▼─────┐  ┌──▼─────────┐
    │ Payment    │  │ Inventory  │  │ Notification│
    │ Service    │  │ Service    │  │ Service     │
    └────────────┘  └────────────┘  └─────────────┘
```

---

## Data Pipeline Architecture

### BigQuery + Cloud Storage
**Pattern**: Data lake and data warehouse

```
Cloud Storage (Data Lake)
    ├── raw/          # Raw ingested data (Parquet, Avro)
    ├── processed/    # Cleaned, transformed data
    └── archive/      # Historical data

BigQuery (Data Warehouse)
    ├── raw_dataset       # Raw tables (external or native)
    ├── staging_dataset   # Intermediate transformations
    └── analytics_dataset # Business-ready data
```

**Best Practices**:
```sql
-- Good: Partitioned and clustered table
CREATE TABLE analytics.user_events (
  event_id STRING,
  user_id STRING,
  event_type STRING,
  event_data JSON,
  event_timestamp TIMESTAMP
)
PARTITION BY DATE(event_timestamp)
CLUSTER BY user_id, event_type
OPTIONS(
  partition_expiration_days=90,
  require_partition_filter=true
);

-- Query with partition filter (efficient)
SELECT user_id, COUNT(*) as event_count
FROM analytics.user_events
WHERE DATE(event_timestamp) BETWEEN '2024-01-01' AND '2024-01-31'
  AND event_type = 'purchase'
GROUP BY user_id;
```

---

## Hybrid & Multi-Cloud Patterns

### Anthos for Multi-Cloud Kubernetes
**Use case**: Run workloads across GCP, AWS, on-prem

```yaml
# Good: Standard Kubernetes resources work everywhere
apiVersion: v1
kind: Service
metadata:
  name: frontend
  annotations:
    cloud.google.com/load-balancer-type: "Internal"  # GCP-specific
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 8080
```

**Considerations**:
- ✅ Use standard Kubernetes APIs
- ✅ Abstract cloud-specific features (load balancers, storage)
- ✅ Use Config Connector for GCP resources in K8s
- ❌ Avoid cloud-specific CRDs in shared manifests

---

## Resiliency Patterns

### Circuit Breaker
```go
import "github.com/sony/gobreaker"

// Good: Circuit breaker for external dependencies
var cb *gobreaker.CircuitBreaker

func init() {
    cb = gobreaker.NewCircuitBreaker(gobreaker.Settings{
        Name:        "payment-service",
        MaxRequests: 5,
        Interval:    time.Minute,
        Timeout:     30 * time.Second,
        ReadyToTrip: func(counts gobreaker.Counts) bool {
            failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
            return counts.Requests >= 3 && failureRatio >= 0.6
        },
    })
}

func processPayment(ctx context.Context, amount decimal.Decimal) error {
    _, err := cb.Execute(func() (interface{}, error) {
        return nil, callPaymentAPI(ctx, amount)
    })
    return err
}
```

### Retry with Exponential Backoff
```go
import "github.com/cenkalti/backoff/v4"

// Good: Exponential backoff for transient failures
func fetchDataWithRetry(ctx context.Context, url string) ([]byte, error) {
    var data []byte

    operation := func() error {
        resp, err := http.Get(url)
        if err != nil {
            return err
        }
        defer resp.Body.Close()

        if resp.StatusCode >= 500 {
            return fmt.Errorf("server error: %d", resp.StatusCode)
        }

        data, err = io.ReadAll(resp.Body)
        return err
    }

    expBackoff := backoff.NewExponentialBackOff()
    expBackoff.MaxElapsedTime = 2 * time.Minute

    err := backoff.Retry(operation, backoff.WithContext(expBackoff, ctx))
    return data, err
}
```

---

## API Gateway Pattern

### Cloud Endpoints or Kong
```yaml
# Cloud Endpoints (OpenAPI spec)
swagger: "2.0"
info:
  title: "My API"
  version: "1.0.0"
host: "api.example.com"
basePath: "/"
schemes:
  - "https"
paths:
  /users:
    get:
      summary: "List users"
      operationId: "listUsers"
      security:
        - api_key: []
      responses:
        200:
          description: "Success"
securityDefinitions:
  api_key:
    type: "apiKey"
    name: "key"
    in: "query"
```

**Alternative: Kong (portable)**
```yaml
# Kong configuration (works on any cloud)
services:
  - name: user-service
    url: http://user-service:8080
    routes:
      - name: user-route
        paths:
          - /users
    plugins:
      - name: rate-limiting
        config:
          minute: 100
      - name: jwt
        config:
          secret_is_base64: false
```

---

## References

- [GCP Architecture Framework](https://cloud.google.com/architecture/framework)
- [Cloud Run Best Practices](https://cloud.google.com/run/docs/tips)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [BigQuery Best Practices](https://cloud.google.com/bigquery/docs/best-practices-performance-overview)
