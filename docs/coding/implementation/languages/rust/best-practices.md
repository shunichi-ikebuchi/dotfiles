# Rust Best Practices

---

## Ownership

```rust
// Ownership transfer
let s1 = String::from("hello");
let s2 = s1; // s1 is no longer valid

// Borrowing
let s1 = String::from("hello");
let len = calculate_length(&s1); // s1 still valid
```

---

## Error Handling

```rust
fn divide(a: f64, b: f64) -> Result<f64, String> {
    if b == 0.0 {
        Err(String::from("Division by zero"))
    } else {
        Ok(a / b)
    }
}

// Usage with ?
fn process() -> Result<(), String> {
    let result = divide(10.0, 2.0)?;
    Ok(())
}
```

---

## Traits

```rust
trait Drawable {
    fn draw(&self);
}

impl Drawable for Circle {
    fn draw(&self) {
        println!("Drawing circle");
    }
}
```
