# Unix Philosophy (Tool Design)

**Build small, focused tools that work together.**

The Unix philosophy, developed over decades of systems programming, provides timeless principles for building robust, composable software. These principles apply beyond Unix—they guide good design in any context.

---

## Core Philosophy

**Do one thing well, and compose simple tools to solve complex problems.**

The power comes not from individual tools, but from their ability to work together seamlessly. Like LEGO blocks, each piece is simple, but combinations are limitless.

---

## Key Principles

### 1. Do One Thing Well

**Single responsibility at every level (functions, modules, services).**

- Focused tools are easier to understand, test, and maintain
- Complexity through composition, not monoliths
- Specialized tools excel at their domain
- Easy to replace or upgrade individual components

**Examples**:

**❌ Monolithic tool (does everything)**:
```bash
# Hypothetical "supertool" that does too much
supertool --fetch-data --transform --validate --store --notify
```

**Downsides**:
- Hard to understand (too many responsibilities)
- Hard to test (too many code paths)
- Hard to maintain (changes affect everything)
- Can't reuse parts independently

**✅ Focused tools (each does one thing)**:
```bash
# Unix pipeline: each tool does one thing
curl https://api.example.com/data | # Fetch data
  jq '.users[] | select(.active)' | # Transform and filter
  validate-schema users.schema.json | # Validate
  save-to-db users | # Store
  notify-admin # Notify
```

**Benefits**:
- Each tool simple and focused
- Easy to test individually
- Can swap components (e.g., use `wget` instead of `curl`)
- Can reuse `jq` for other JSON tasks

**In Code**:

**❌ Monolithic class**:
```typescript
class UserManager {
  validateUser() { /* ... */ }
  saveUser() { /* ... */ }
  sendEmail() { /* ... */ }
  logActivity() { /* ... */ }
  generateReport() { /* ... */ }
}
```

**✅ Focused classes**:
```typescript
class UserValidator {
  validate(user: User): ValidationResult
}

class UserRepository {
  save(user: User): Promise<void>
}

class EmailService {
  send(to: string, subject: string, body: string): Promise<void>
}

class ActivityLogger {
  log(event: ActivityEvent): void
}

class ReportGenerator {
  generate(data: ReportData): Report
}
```

### 2. Composability

**Design components that can be combined in unexpected ways.**

- Loose coupling enables flexibility and reuse
- Standardized interfaces enable interoperability
- Build pipelines from simple components
- Enable creativity through recombination

**Examples**:

**❌ Tightly coupled (can't compose)**:
```typescript
class DataProcessor {
  // Hard-coded to fetch from specific API and save to specific DB
  async process() {
    const data = await this.fetchFromSpecificAPI()
    const transformed = this.transform(data)
    await this.saveToSpecificDB(transformed)
  }
}
```

**Can't**:
- Use a different data source
- Transform without fetching
- Save to a different destination
- Reuse transformation logic elsewhere

**✅ Composable (mix and match)**:
```typescript
// Separate concerns, standard interfaces
interface DataSource<T> {
  fetch(): Promise<T>
}

interface DataTransformer<TIn, TOut> {
  transform(data: TIn): TOut
}

interface DataSink<T> {
  save(data: T): Promise<void>
}

// Compose any source + transformer + sink
async function pipeline<TIn, TOut>(
  source: DataSource<TIn>,
  transformer: DataTransformer<TIn, TOut>,
  sink: DataSink<TOut>
) {
  const data = await source.fetch()
  const transformed = transformer.transform(data)
  await sink.save(transformed)
}

// Mix and match implementations
pipeline(
  new APIDataSource('https://api.example.com'),
  new JSONTransformer(),
  new PostgreSQLSink()
)

pipeline(
  new FileDataSource('data.csv'),
  new CSVTransformer(),
  new S3Sink('bucket-name')
)
```

**Benefits**:
- Can swap components independently
- Reuse transformers across different pipelines
- Test each component in isolation
- Creativity: combine in ways original designer didn't anticipate

### 3. Universal Interfaces

**Agree on common data representations across boundaries.**

- Text/JSON as lingua franca when possible
- Reduces integration friction between tools
- Enables tooling ecosystem to flourish
- Future-proof: standard formats outlive specific tools

**Examples**:

**Unix Text Streams**:
```bash
# All tools speak "lines of text"
ps aux | grep node | awk '{print $2}' | xargs kill
# ps outputs text → grep filters text → awk extracts text → xargs consumes text
```

**Web APIs (JSON)**:
```bash
# All tools speak JSON
curl https://api.github.com/users/octocat |
  jq '.followers' |
  echo "Followers: $(cat)"
```

**In Code (Standard Interfaces)**:

**❌ Proprietary format**:
```typescript
// Custom binary format, requires specific library
class DataExporter {
  exportToCustomFormat(data: any): Buffer {
    return proprietarySerialize(data)
  }
}

// Only works with tools that understand this custom format
```

**✅ Standard format (JSON, CSV, Protocol Buffers)**:
```typescript
// Standard JSON format, works with anything
class DataExporter {
  exportToJSON(data: any): string {
    return JSON.stringify(data, null, 2)
  }
}

// Works with: jq, any HTTP client, databases, other languages, etc.
```

**Benefits**:
- Tool-agnostic: Any tool that speaks JSON can consume/produce
- Human-readable: Can inspect and debug
- Version-controllable: Text diffs show changes
- Ecosystem: Reuse existing tools (jq, grep, etc.)

### 4. Single Source of Truth (Text Files)

**Text files as the ultimate source of truth (configuration, documentation, data).**

- Human-readable and editable
- Version-controllable (git diff shows changes)
- Tool-agnostic (any editor, any language)
- Avoids vendor lock-in and proprietary formats
- Enables collaboration through standard tools

**Examples**:

**❌ Database as configuration source**:
```sql
-- Configuration in database (hard to version, diff, review)
INSERT INTO config (key, value) VALUES ('max_retries', '3');
INSERT INTO config (key, value) VALUES ('timeout_ms', '5000');
```

**Problems**:
- Can't see history of changes
- Can't review in PR
- Hard to replicate across environments
- Requires database access to change

**✅ Text file as configuration source**:
```yaml
# config.yaml (version-controlled, diffable, reviewable)
retries:
  max: 3
  timeout_ms: 5000
```

**Benefits**:
- Git tracks every change
- PR reviews show diffs clearly
- Easy to replicate (copy file)
- No special tools needed to edit

**Application: Infrastructure as Code**:

**❌ Manual infrastructure (ClickOps)**:
```
1. Log into AWS console
2. Click "Create EC2 instance"
3. Choose settings manually
4. Click "Launch"
```

**Problems**:
- No history
- Can't reproduce
- No code review
- Manual errors

**✅ Infrastructure as Code (Terraform)**:
```hcl
# main.tf (version-controlled infrastructure)
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name = "WebServer"
  }
}
```

**Benefits**:
- Version controlled (see all changes)
- Code review before apply
- Reproducible across environments
- Automated deployment

### 5. Automation & Leverage

**Build tools that amplify your effort.**

- Scripts and automation compound value over time
- Invest in tooling for repetitive tasks
- One-time effort, infinite reuse
- Codify knowledge into executable tools

**Examples**:

**❌ Manual repetitive work**:
```
1. SSH into server
2. Check logs
3. Identify error pattern
4. Search code for relevant files
5. Make change
6. Restart service
7. Verify fix
8. Repeat for next server
```

**Time cost**: 30 minutes × N servers

**✅ Automated script**:
```bash
#!/bin/bash
# deploy-fix.sh

SERVERS=("server1" "server2" "server3")
FIX_SCRIPT="
  sudo systemctl stop myapp
  sudo sed -i 's/old_config/new_config/' /etc/myapp/config
  sudo systemctl start myapp
  sudo systemctl status myapp
"

for server in "${SERVERS[@]}"; do
  echo "Deploying to $server..."
  ssh "$server" "$FIX_SCRIPT"
done

echo "Deployment complete"
```

**Time cost**: 5 minutes to write script once, 1 minute to run on all servers

**Benefits**:
- Consistency: Same fix applied everywhere
- Speed: Parallel execution
- Reusability: Run again if issue recurs
- Knowledge capture: Script documents the fix

**Compounding Value**:

First use: 5 min to write + 1 min to run = 6 min (vs 30 min manual)
Second use: 1 min to run (saved 29 min)
Third use: 1 min to run (saved 29 min)
...

After 3 uses: Saved 52 minutes. After 10 uses: Saved 286 minutes.

**Investment**: 5 minutes
**Return**: Hours or days of time saved

---

## Anti-Patterns

### 1. Monolithic Tools

**Problem**: Do everything in one place (hard to test, maintain, reuse)

**Example**: Massive framework that handles HTTP, database, email, auth, logging, etc.

**Solution**: Separate concerns, use focused libraries

### 2. Proprietary Formats

**Problem**: Lock users into your ecosystem

**Example**: Custom binary data format, special file types

**Solution**: Use standard formats (JSON, CSV, YAML, Protocol Buffers)

### 3. Manual Processes

**Problem**: Repeated tasks that should be scripted

**Example**: Manually deploying to production every release

**Solution**: Automate with scripts, CI/CD pipelines

### 4. Over-Coupling

**Problem**: Components that can't function independently

**Example**: Service A can't run without Service B, even for testing

**Solution**: Design for loose coupling, use interfaces and dependency injection

### 5. Feature Creep

**Problem**: Tools that grow beyond their original focused purpose

**Example**: Text editor that becomes an OS (Emacs joke)

**Solution**: Resist adding features that violate single responsibility

---

## Applying Unix Philosophy in Modern Development

### Example: Building a Data Pipeline

**Monolithic approach (anti-pattern)**:
```typescript
class DataPipeline {
  async run() {
    // 500 lines of code doing everything
    const data = await this.fetchFromAPI()
    const cleaned = this.cleanData(data)
    const validated = this.validateData(cleaned)
    const transformed = this.transformData(validated)
    await this.saveToDatabase(transformed)
    await this.sendNotification()
  }
}
```

**Unix philosophy approach**:
```typescript
// 1. Do One Thing Well
interface Stage<TIn, TOut> {
  execute(input: TIn): Promise<TOut>
}

class FetchStage implements Stage<void, RawData> {
  async execute(): Promise<RawData> {
    return fetchFromAPI()
  }
}

class CleanStage implements Stage<RawData, CleanData> {
  async execute(data: RawData): Promise<CleanData> {
    return cleanData(data)
  }
}

class ValidateStage implements Stage<CleanData, ValidData> {
  async execute(data: CleanData): Promise<ValidData> {
    return validateData(data)
  }
}

class TransformStage implements Stage<ValidData, TransformedData> {
  async execute(data: ValidData): Promise<TransformedData> {
    return transformData(data)
  }
}

class SaveStage implements Stage<TransformedData, void> {
  async execute(data: TransformedData): Promise<void> {
    await saveToDatabase(data)
  }
}

// 2. Composability
class Pipeline<T> {
  private stages: Stage<any, any>[] = []

  add<TOut>(stage: Stage<T, TOut>): Pipeline<TOut> {
    this.stages.push(stage)
    return this as any
  }

  async run(input: T): Promise<any> {
    let result = input
    for (const stage of this.stages) {
      result = await stage.execute(result)
    }
    return result
  }
}

// 3. Use it
const pipeline = new Pipeline<void>()
  .add(new FetchStage())
  .add(new CleanStage())
  .add(new ValidateStage())
  .add(new TransformStage())
  .add(new SaveStage())

await pipeline.run()
```

**Benefits**:
- Each stage testable independently
- Can swap stages (e.g., different data source)
- Can reuse stages in different pipelines
- Easy to add new stages
- Clear separation of concerns

---

## Golden Rule

**If you can't pipe it, compose it, or automate it, you've probably made it too complex.**

Build sharp, focused tools that do one thing excellently and play well with others.

**Ask yourself**:
1. **Does this tool do one thing well?** (or many things poorly?)
2. **Can I compose this with other tools?** (or is it a silo?)
3. **Is this automatable?** (or does it require manual intervention?)
4. **Does it use standard interfaces?** (or a proprietary format?)

If yes to all → good Unix-style tool.
If no → reconsider design.

---

## Summary

**Unix Philosophy principles**:

1. **Do One Thing Well**: Single responsibility, focused tools
2. **Composability**: Design for recombination and reuse
3. **Universal Interfaces**: Standard data formats (text, JSON)
4. **Single Source of Truth**: Text files for config, docs, data
5. **Automation & Leverage**: Build tools that amplify effort

**The Goal**: Build systems from simple, composable pieces rather than monolithic complexity.

**The Result**: Flexible, maintainable, reusable software that stands the test of time.

**Remember**: The Unix tools from the 1970s (grep, sed, awk) are still in daily use because they follow these principles. Build your tools with the same philosophy, and they'll serve you for decades.
