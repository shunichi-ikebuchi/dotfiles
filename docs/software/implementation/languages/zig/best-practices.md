# Zig Best Practices

---

## Allocators

```zig
const allocator = std.heap.page_allocator;
const list = try std.ArrayList(i32).init(allocator);
defer list.deinit();
```

---

## Error Handling

```zig
fn divide(a: f64, b: f64) !f64 {
    if (b == 0) return error.DivisionByZero;
    return a / b;
}

// Usage
const result = try divide(10, 2);
```

---

## Comptime

```zig
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}
```
