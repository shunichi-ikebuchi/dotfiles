# Go Best Practices

Comprehensive guide to writing idiomatic Go code.

---

## Error Handling

### Always Check Errors
```go
// Bad
result, _ := doSomething()

// Good
result, err := doSomething()
if err != nil {
    return fmt.Errorf("failed to do something: %w", err)
}
```

### Wrap Errors with Context
```go
if err := saveUser(user); err != nil {
    return fmt.Errorf("failed to save user %s: %w", user.ID, err)
}
```

### Use errors.Is and errors.As
```go
if errors.Is(err, ErrNotFound) {
    // Handle not found
}

var validationErr *ValidationError
if errors.As(err, &validationErr) {
    // Handle validation error
}
```

---

## Concurrency

### Use Goroutines Wisely
```go
// Launch goroutine with error handling
go func() {
    if err := processData(data); err != nil {
        log.Printf("failed to process: %v", err)
    }
}()
```

### Use Context for Cancellation
```go
func fetchData(ctx context.Context, url string) error {
    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return err
    }
    resp, err := http.DefaultClient.Do(req)
    // ...
}
```

### Synchronize with WaitGroup
```go
var wg sync.WaitGroup
for _, item := range items {
    wg.Add(1)
    go func(item Item) {
        defer wg.Done()
        process(item)
    }(item)
}
wg.Wait()
```

---

## Interfaces

### Accept Interfaces, Return Structs
```go
// Good
func ProcessData(r io.Reader) (*Result, error) {
    // ...
}
```

### Keep Interfaces Small
```go
type Reader interface {
    Read(p []byte) (n int, err error)
}
```

---

## Testing

See [testing.md](./testing.md) for detailed testing strategies.

## Patterns

See [patterns.md](./patterns.md) for common Go design patterns.
