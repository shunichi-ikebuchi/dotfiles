# Go Coding Guidelines

Go-specific instructions for AI coding agents working on Go projects.

---

## Quick Reference

### Idiomatic Go
- ✅ Follow the [Effective Go](https://go.dev/doc/effective_go) guidelines
- ✅ Use `gofmt` for formatting (non-negotiable)
- ✅ Run `go vet` and `golangci-lint` before committing
- ✅ Write clear, simple code (Go values clarity over cleverness)
- ✅ Use short variable names in small scopes (`i`, `err`, `ctx`)
- ✅ Use descriptive names in larger scopes

### Error Handling
- ✅ Check errors immediately: `if err != nil { return err }`
- ✅ Wrap errors with context: `fmt.Errorf("failed to X: %w", err)`
- ✅ Use `errors.Is()` and `errors.As()` for error checking
- ❌ Never ignore errors with `_`

### Concurrency
- ✅ Use goroutines for concurrent operations
- ✅ Use channels for communication
- ✅ Use `sync.WaitGroup` for synchronization
- ✅ Use `context.Context` for cancellation and timeouts
- ❌ Avoid shared mutable state (use channels or `sync.Mutex`)

### Project Structure
```
project/
├── cmd/            # Main applications
│   └── myapp/
│       └── main.go
├── internal/       # Private application code
│   ├── service/
│   └── repository/
├── pkg/            # Public library code
├── api/            # API definitions (proto, OpenAPI)
├── scripts/        # Build and deployment scripts
├── go.mod
└── go.sum
```

---

## Detailed Guidelines

For comprehensive Go best practices, see:
- **[Best Practices](./best-practices.md)**: Error handling, concurrency, performance
- **[Testing](./testing.md)**: Table-driven tests, benchmarks, examples
- **[Patterns](./patterns.md)**: Common Go design patterns

---

## Common Pitfalls to Avoid

### ❌ Ignoring Errors
```go
// Bad: Silent failure
result, _ := doSomething()

// Good: Handle errors
result, err := doSomething()
if err != nil {
    return fmt.Errorf("failed to do something: %w", err)
}
```

### ❌ Not Using defer for Cleanup
```go
// Bad: Manual cleanup
f, err := os.Open("file.txt")
if err != nil {
    return err
}
// ... code ...
f.Close()

// Good: Defer cleanup
f, err := os.Open("file.txt")
if err != nil {
    return err
}
defer f.Close()
// ... code ...
```

### ❌ Copying Mutexes
```go
// Bad: Mutex copied
type Counter struct {
    mu    sync.Mutex
    count int
}
func (c Counter) Increment() {  // c is a copy!
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

// Good: Pointer receiver
func (c *Counter) Increment() {  // c is a pointer
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}
```

---

## Style Conventions

### Naming
- **Interfaces**: Single-method interfaces end in `-er` (e.g., `Reader`, `Writer`, `Closer`)
- **Acronyms**: Keep uppercase (e.g., `HTTPServer`, `URLParser`, `IDGenerator`)
- **Getters**: Omit `Get` prefix (e.g., `user.Name()` not `user.GetName()`)
- **Setters**: Use `Set` prefix (e.g., `user.SetName(name)`)

### Package Names
- Lowercase, single-word names (e.g., `http`, `json`, `database`)
- No underscores or mixedCaps
- Should be descriptive but concise

### Comments
- Package comment: Above package declaration
- Exported identifiers: Start with identifier name
```go
// Package http provides HTTP client and server implementations.
package http

// Get sends an HTTP GET request.
func Get(url string) (*Response, error) { ... }
```

---

## Recommended Tools

- **Formatter**: `gofmt` (or `goimports`)
- **Linter**: `golangci-lint` (runs multiple linters)
- **Testing**: Built-in `go test`
- **Coverage**: `go test -cover`
- **Profiling**: `pprof`
- **Dependency Management**: `go mod`

---

## Integration with General Principles

Go code should also follow:
- **[Code Quality Principles](../general/code-quality.md)**: Explicitness, locality, fail-fast
- **[Unix Philosophy](../general/unix-philosophy.md)**: Simplicity, composability

---

## When to Escalate

Consult human developers for:
- **API design decisions**: Public package interfaces
- **Concurrency patterns**: Complex goroutine coordination
- **Performance trade-offs**: Optimization vs. readability
- **Breaking changes**: Modifying exported APIs
