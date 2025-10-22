# Security-First Design Principles

**Design principles for building secure, resilient systems from the ground up.**

Security is not a feature to be added later—it must be a fundamental design consideration from the start. These principles guide how we architect, implement, and operate secure systems.

---

## Overview: Why Security-First Matters

**Common Security Problems**:
- **Retrofitting security**: Adding security after design is costly and incomplete
- **Default insecurity**: Systems that are insecure unless explicitly hardened
- **Single point of failure**: One vulnerability compromises entire system
- **Excessive privileges**: Components have more access than needed
- **Implicit trust**: Trusting network, users, or components without verification

**Security as a System**: Security requires multiple layers working together. No single measure is sufficient.

---

## 1. Security First

**Security considerations must be part of every design decision, not an afterthought.**

### Core Idea

Evaluate security implications at every stage of development—requirements, design, implementation, testing, and deployment. Security requirements should be treated with the same priority as functional requirements.

### Why It Matters

- **Cheaper to fix early**: Security issues found in design cost 10-100x less than in production
- **Better architecture**: Security constraints drive better design decisions
- **Reduces attack surface**: Proactive design eliminates vulnerabilities before they exist
- **Compliance by design**: Meets regulatory requirements without retrofitting

### Principles

1. **Threat Modeling Early**: Identify threats during design phase
2. **Security Requirements**: Document security requirements alongside functional requirements
3. **Risk-Based Approach**: Prioritize security based on risk assessment
4. **Security Reviews**: Code reviews must include security considerations
5. **Security Testing**: Automated security testing in CI/CD pipeline

### Example: API Design

**❌ Violates Security First (Security as afterthought)**:
```typescript
// Design: Build API first, add auth later
class UserAPI {
  // Just expose everything publicly
  getUser(id: string): User {
    return database.users.findById(id);
  }

  updateUser(id: string, data: Partial<User>): User {
    return database.users.update(id, data);
  }

  deleteUser(id: string): void {
    database.users.delete(id);
  }
}

// Later: "Oh, we need authentication!"
// Now have to retrofit auth, audit logging, rate limiting, etc.
```

**✅ Follows Security First (Security from start)**:
```typescript
// Design: Security requirements defined upfront
interface SecurityContext {
  userId: string;
  roles: string[];
  permissions: string[];
  sessionId: string;
}

interface AuditLog {
  action: string;
  userId: string;
  resourceId: string;
  timestamp: Date;
  outcome: 'success' | 'failure';
}

class UserAPI {
  constructor(
    private database: Database,
    private authz: AuthorizationService,
    private audit: AuditService,
    private rateLimiter: RateLimiter
  ) {}

  async getUser(id: string, context: SecurityContext): Promise<User> {
    // 1. Rate limiting
    await this.rateLimiter.check(context.userId);

    // 2. Authorization check
    if (!this.authz.canRead(context, 'user', id)) {
      await this.audit.log({
        action: 'getUser',
        userId: context.userId,
        resourceId: id,
        outcome: 'failure',
      });
      throw new ForbiddenError('Insufficient permissions');
    }

    // 3. Retrieve data
    const user = await this.database.users.findById(id);

    // 4. Audit log
    await this.audit.log({
      action: 'getUser',
      userId: context.userId,
      resourceId: id,
      outcome: 'success',
    });

    // 5. Data filtering (don't expose sensitive fields to unauthorized users)
    return this.filterSensitiveFields(user, context);
  }

  private filterSensitiveFields(user: User, context: SecurityContext): User {
    // Only admins can see SSN, full address, etc.
    if (context.roles.includes('admin')) {
      return user;
    }

    // Regular users see limited data
    return {
      id: user.id,
      name: user.name,
      email: user.email,
      // Omit: ssn, fullAddress, creditCard, etc.
    };
  }
}
```

---

## 2. Secure by Default

**Systems should be secure in their default configuration, not requiring users to opt-in to security.**

### Core Idea

The default state of a system should be the most secure state. Users should have to explicitly opt-out of security features, not opt-in. This prevents security vulnerabilities from misconfiguration or oversight.

### Why It Matters

- **Prevents misconfiguration**: Most vulnerabilities come from insecure defaults
- **Protects novice users**: Users don't need to be security experts
- **Reduces attack surface**: Unnecessary features are disabled by default
- **Enforces best practices**: Secure configuration is the path of least resistance

### Principles

1. **Deny by Default**: Access is denied unless explicitly granted
2. **Least Functionality**: Only essential features enabled by default
3. **Secure Defaults**: Strongest encryption, authentication enabled by default
4. **Fail Securely**: Failures result in secure state, not open state
5. **No Default Credentials**: Force password change on first use

### Example: Database Access

**❌ Violates Secure by Default (Insecure defaults)**:
```typescript
// Bad: Database client with permissive defaults
const db = new DatabaseClient({
  host: 'db.example.com',
  // No TLS by default (insecure)
  // No authentication required (insecure)
  // Public access allowed (insecure)
  // No query timeout (DoS risk)
  // No connection limit (resource exhaustion)
});

// User has to remember to enable security features
db.enableTLS();
db.requireAuth({ user: 'app', password: 'xxx' });
db.restrictToPrivateNetwork();
```

**✅ Follows Secure by Default (Secure defaults)**:
```typescript
// Good: Database client with secure defaults
const db = new DatabaseClient({
  host: 'db.example.com',

  // TLS required by default (cannot be disabled in production)
  tls: {
    enabled: true,
    minVersion: 'TLSv1.3',
    rejectUnauthorized: true,
  },

  // Authentication required (no default/anonymous access)
  auth: {
    user: process.env.DB_USER,  // No hardcoded credentials
    password: process.env.DB_PASSWORD,  // From secrets manager
  },

  // Connection limits by default
  pool: {
    min: 2,
    max: 10,
    idleTimeoutMillis: 30000,
  },

  // Query timeout by default (prevent DoS)
  statement_timeout: 30000,  // 30 seconds

  // Logging enabled by default (audit trail)
  logging: {
    enabled: true,
    level: 'info',
    logQueries: true,
    logConnections: true,
  },
});

// To explicitly opt-out (requires justification)
if (process.env.NODE_ENV === 'development') {
  // Only for local dev, never in production
  db.config.allowInsecureLocalhost = true;
}
```

### Example: API Endpoints

**❌ Violates Secure by Default**:
```typescript
// Bad: Open by default
app.get('/api/users', (req, res) => {
  // No authentication required
  // No authorization check
  // No rate limiting
  const users = db.getAllUsers();
  res.json(users);
});
```

**✅ Follows Secure by Default**:
```typescript
// Good: Secure by default
app.get('/api/users',
  authenticateRequest,      // Require authentication (default)
  authorizeRole(['admin']), // Require specific role (default deny)
  rateLimiter({ max: 100, window: '15m' }), // Rate limit by default
  validateInput(GetUsersSchema),  // Input validation by default
  async (req, res) => {
    const users = await db.getUsers({
      limit: Math.min(req.query.limit || 10, 100), // Max limit enforced
    });

    // Filter sensitive fields by default
    const safeUsers = users.map(u => ({
      id: u.id,
      name: u.name,
      // Don't expose: email, phone, ssn by default
    }));

    res.json(safeUsers);
  }
);
```

---

## 3. Defense in Depth

**Use multiple layers of security controls so that if one fails, others still provide protection.**

### Core Idea

Don't rely on a single security control. Layer multiple independent security mechanisms so that an attacker must compromise multiple layers to succeed.

### Why It Matters

- **No single point of failure**: One vulnerability doesn't compromise entire system
- **Reduces impact**: Breaches are contained to one layer
- **Provides redundancy**: Backup controls if primary fails
- **Increases attacker cost**: Must bypass multiple defenses

### Security Layers

```
User/Client
    ↓
┌─────────────────────────────────────────┐
│ Layer 1: Network Security               │
│ - Firewall, WAF, DDoS protection       │
│ - VPC, Security Groups, NACLs           │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Layer 2: Application Security           │
│ - Authentication (MFA)                  │
│ - Authorization (RBAC/ABAC)             │
│ - Input validation                      │
│ - Rate limiting                         │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Layer 3: Data Security                  │
│ - Encryption at rest (KMS)              │
│ - Encryption in transit (TLS)           │
│ - Data masking/redaction                │
│ - Access logging                        │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Layer 4: Infrastructure Security        │
│ - OS hardening                          │
│ - Patch management                      │
│ - Least privilege (IAM)                 │
│ - Security monitoring                   │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Layer 5: Physical Security              │
│ - Data center security (Cloud provider) │
│ - Hardware security modules (HSM)       │
└─────────────────────────────────────────┘
```

### Example: Payment Processing

```typescript
// Defense in Depth: Multiple layers protecting payment data
class PaymentProcessor {
  async processPayment(
    payment: PaymentRequest,
    context: SecurityContext
  ): Promise<PaymentResult> {
    // Layer 1: Network - Already filtered by firewall, WAF
    // Layer 2: Application security

    // 2a. Rate limiting (prevent brute force)
    await this.rateLimiter.check(context.userId, 'payment', { max: 10, window: '1h' });

    // 2b. Authentication (verify user identity)
    if (!context.authenticated) {
      throw new UnauthorizedException('Authentication required');
    }

    // 2c. Authorization (check permissions)
    if (!this.authz.can(context, 'create', 'payment')) {
      throw new ForbiddenError('Insufficient permissions');
    }

    // 2d. Input validation (prevent injection attacks)
    const validatedPayment = this.validator.validate(PaymentSchema, payment);

    // 2e. Additional MFA for high-value transactions
    if (payment.amount > 10000) {
      await this.mfa.verify(context.userId, payment.mfaCode);
    }

    // Layer 3: Data security

    // 3a. Tokenize credit card (never store raw PAN)
    const token = await this.tokenizer.tokenize(payment.creditCard);

    // 3b. Encrypt sensitive data before storing
    const encryptedData = await this.crypto.encrypt({
      amount: payment.amount,
      token: token,
      userId: context.userId,
    });

    // 3c. Store with encryption at rest (database-level encryption)
    const transaction = await this.database.transactions.create({
      data: encryptedData,
      userId: context.userId,
      timestamp: new Date(),
    });

    // 3d. Audit log (immutable, encrypted log)
    await this.auditLog.log({
      action: 'payment.process',
      userId: context.userId,
      amount: payment.amount,
      transactionId: transaction.id,
      outcome: 'initiated',
    });

    // Layer 4: Infrastructure
    // - Payment processor runs in isolated VPC
    // - IAM role with minimal permissions
    // - Security monitoring alerts on anomalies

    // Process with payment gateway (also has its own security layers)
    const result = await this.paymentGateway.charge({
      token: token,
      amount: payment.amount,
    });

    // Audit log final result
    await this.auditLog.log({
      action: 'payment.process',
      userId: context.userId,
      transactionId: transaction.id,
      outcome: result.success ? 'success' : 'failure',
    });

    return result;
  }
}
```

---

## 4. Least Privilege

**Every component should have only the minimum permissions necessary to perform its function.**

### Core Idea

Users, processes, and systems should operate with the minimum set of privileges required. This limits the potential damage from accidents or attacks.

### Why It Matters

- **Limits blast radius**: Compromised component has limited access
- **Reduces attack surface**: Fewer privileges to exploit
- **Easier to audit**: Clear separation of responsibilities
- **Compliance**: Required by many security standards

### Example: Service Accounts

**❌ Violates Least Privilege**:
```typescript
// Bad: Service has admin access to everything
const s3Client = new S3Client({
  credentials: {
    // IAM role: arn:aws:iam::123456789:role/AdminRole
    // Permissions: Administrator access to all AWS services
  }
});

// Service can now:
// - Delete all S3 buckets
// - Terminate all EC2 instances
// - Read all secrets
// - Modify IAM policies
// Even though it only needs to read/write to one S3 bucket!
```

**✅ Follows Least Privilege**:
```typescript
// Good: Service has minimal, specific permissions
const s3Client = new S3Client({
  credentials: {
    // IAM role: arn:aws:iam::123456789:role/ImageServiceRole
    // Permissions (IAM policy):
    // {
    //   "Version": "2012-10-17",
    //   "Statement": [{
    //     "Effect": "Allow",
    //     "Action": [
    //       "s3:GetObject",
    //       "s3:PutObject"
    //     ],
    //     "Resource": "arn:aws:s3:::my-app-images/*"
    //   }]
    // }
  }
});

// Service can ONLY:
// - Read objects from my-app-images bucket
// - Write objects to my-app-images bucket
// Nothing else!
```

### Example: Database Access

**❌ Violates Least Privilege**:
```sql
-- Bad: Application uses database superuser
GRANT ALL PRIVILEGES ON DATABASE myapp TO app_user;

-- Now app_user can:
-- - Drop entire database
-- - Create/delete any table
-- - Grant permissions to other users
-- - Read all data (including sensitive tables)
```

**✅ Follows Least Privilege**:
```sql
-- Good: Application has minimal, specific permissions
-- Read-only user for analytics service
CREATE USER analytics_reader WITH PASSWORD 'xxx';
GRANT CONNECT ON DATABASE myapp TO analytics_reader;
GRANT SELECT ON TABLE orders, products TO analytics_reader;
-- Can ONLY read from orders and products tables

-- Read-write user for application service
CREATE USER app_writer WITH PASSWORD 'xxx';
GRANT CONNECT ON DATABASE myapp TO app_writer;
GRANT SELECT, INSERT, UPDATE ON TABLE orders, users TO app_writer;
-- Can ONLY read/write to orders and users tables (not DELETE)

-- Admin user for migrations (used only during deployments)
CREATE USER migration_admin WITH PASSWORD 'xxx';
GRANT ALL PRIVILEGES ON DATABASE myapp TO migration_admin;
-- Only used by CI/CD during schema migrations, not by running application
```

---

## 5. Zero Trust

**Never trust, always verify. Don't assume network location or identity equals security.**

### Core Idea

Traditional security models trusted users inside the network perimeter. Zero Trust assumes breach and verifies every request, regardless of source.

### Why It Matters

- **Prevents lateral movement**: Attacker inside network can't freely move
- **Works for remote work**: No VPN needed, access based on identity
- **Cloud-native**: Aligns with distributed, cloud-based architectures
- **Reduces insider threat**: Every access is verified and logged

### Zero Trust Principles

1. **Verify explicitly**: Authenticate and authorize every request
2. **Least privilege access**: Grant minimum necessary access
3. **Assume breach**: Monitor and log everything, detect anomalies

### Example: Service-to-Service Communication

**❌ Violates Zero Trust (Implicit trust)**:
```typescript
// Bad: Trust based on network location
class OrderService {
  async createOrder(order: Order): Promise<string> {
    // No authentication - assumes caller is trusted because it's on internal network
    const orderId = await this.database.orders.create(order);

    // Call inventory service (no auth, just HTTP)
    await fetch('http://inventory-service/reserve', {
      method: 'POST',
      body: JSON.stringify({ items: order.items }),
    });

    return orderId;
  }
}
```

**✅ Follows Zero Trust**:
```typescript
// Good: Verify every request, even internal
class OrderService {
  constructor(
    private auth: ServiceAuthenticator,
    private crypto: CryptoService
  ) {}

  async createOrder(
    order: Order,
    callerContext: ServiceContext  // Who is calling this?
  ): Promise<string> {
    // 1. Verify caller identity (mutual TLS or JWT)
    if (!await this.auth.verifyService(callerContext)) {
      throw new UnauthorizedException('Invalid service identity');
    }

    // 2. Authorize caller (is this service allowed to create orders?)
    if (!this.auth.hasPermission(callerContext, 'orders:create')) {
      throw new ForbiddenError('Service not authorized to create orders');
    }

    // 3. Create order
    const orderId = await this.database.orders.create(order);

    // 4. Call inventory service with authentication
    const serviceToken = await this.auth.getServiceToken('order-service');

    const response = await fetch('https://inventory-service.internal/reserve', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${serviceToken}`,
        'Content-Type': 'application/json',
        'X-Request-ID': crypto.randomUUID(),  // Correlation ID for tracing
      },
      body: JSON.stringify({ items: order.items }),
      // Use mTLS (mutual TLS) for service-to-service
      agent: this.createMTLSAgent(),
    });

    // 5. Verify response signature
    if (!await this.crypto.verifySignature(response)) {
      throw new Error('Response signature verification failed');
    }

    // 6. Audit log
    await this.audit.log({
      action: 'order.created',
      caller: callerContext.serviceId,
      orderId: orderId,
      timestamp: new Date(),
    });

    return orderId;
  }

  private createMTLSAgent(): https.Agent {
    return new https.Agent({
      cert: fs.readFileSync('/certs/client-cert.pem'),
      key: fs.readFileSync('/certs/client-key.pem'),
      ca: fs.readFileSync('/certs/ca-cert.pem'),
      rejectUnauthorized: true,  // Verify server certificate
    });
  }
}
```

---

## Applying Security-First Principles

### Checklist for Every New Feature

#### Design Phase
- [ ] **Threat Model**: What can go wrong? Who are the attackers?
- [ ] **Security Requirements**: What security controls are needed?
- [ ] **Data Classification**: What sensitive data is involved?
- [ ] **Access Control**: Who should have access? What permissions?
- [ ] **Audit Requirements**: What needs to be logged?

#### Implementation Phase
- [ ] **Secure by Default**: Is the default configuration secure?
- [ ] **Input Validation**: All inputs validated and sanitized?
- [ ] **Output Encoding**: Outputs properly encoded (prevent XSS)?
- [ ] **Authentication**: Every request authenticated?
- [ ] **Authorization**: Permissions checked before every action?
- [ ] **Encryption**: Sensitive data encrypted at rest and in transit?
- [ ] **Least Privilege**: Minimum permissions granted?
- [ ] **Error Handling**: Errors don't leak sensitive information?

#### Testing Phase
- [ ] **Security Tests**: Automated security tests in CI/CD?
- [ ] **Penetration Testing**: Manual security testing performed?
- [ ] **Dependency Scanning**: Third-party libraries scanned for vulnerabilities?
- [ ] **SAST/DAST**: Static and dynamic analysis tools run?

#### Deployment Phase
- [ ] **Secrets Management**: No secrets in code or environment variables?
- [ ] **Monitoring**: Security events logged and monitored?
- [ ] **Incident Response**: Response plan documented?
- [ ] **Backup/Recovery**: Disaster recovery plan in place?

---

## Common Anti-Patterns

### ❌ "We'll add security later"
Security retrofitting is expensive and incomplete. Security must be designed from the start.

### ❌ "Security vs. Usability"
False dichotomy. Good security design enhances usability (e.g., SSO, passwordless auth).

### ❌ "We're too small to be a target"
Attackers use automated tools that don't discriminate by company size.

### ❌ "Security through obscurity"
Hiding implementation details is not security. Use proper cryptography and access controls.

### ❌ "Compliance = Security"
Compliance is minimum baseline. True security requires more.

### ❌ "Trust the network"
Network location doesn't equal security. Use Zero Trust model.

---

## Tools & Practices

### Static Analysis
- **SAST**: SonarQube, Checkmarx, Semgrep
- **Dependency Scanning**: Snyk, Dependabot, OWASP Dependency-Check
- **Secret Scanning**: GitGuardian, TruffleHog, git-secrets

### Dynamic Analysis
- **DAST**: OWASP ZAP, Burp Suite
- **Penetration Testing**: Regular security assessments
- **Fuzzing**: AFL, LibFuzzer for finding crashes

### Security in CI/CD
```yaml
# GitHub Actions example
name: Security Checks

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Dependency vulnerability scanning
      - name: Run Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}

      # Static code analysis
      - name: Run Semgrep
        uses: returntocorp/semgrep-action@v1

      # Secret scanning
      - name: TruffleHog
        uses: trufflesecurity/trufflehog@main

      # Container scanning
      - name: Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master

      # License compliance
      - name: FOSSA
        uses: fossas/fossa-action@main
```

---

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Controls](https://www.cisecurity.org/controls)
- [Zero Trust Architecture (NIST SP 800-207)](https://csrc.nist.gov/publications/detail/sp/800-207/final)
- [OWASP Application Security Verification Standard](https://owasp.org/www-project-application-security-verification-standard/)
- [Principle of Least Privilege (PoLP)](https://www.cisa.gov/topics/cyber-threats-and-advisories/principle-least-privilege)
