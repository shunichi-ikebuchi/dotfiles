# Rust Coding Guidelines

Rust-specific instructions for AI coding agents.

---

## Quick Reference

### Ownership & Borrowing
- ✅ Understand ownership rules
- ✅ Use references (`&T`, `&mut T`) appropriately
- ✅ Leverage lifetimes for complex borrowing
- ❌ Avoid unnecessary cloning

### Error Handling
- ✅ Use `Result<T, E>` for recoverable errors
- ✅ Use `Option<T>` for optional values
- ✅ Use `?` operator for error propagation
- ❌ Avoid `unwrap()` in production code

### Memory Safety
- ✅ Rust prevents data races at compile time
- ✅ Use `unsafe` only when absolutely necessary
- ✅ Prefer safe abstractions

---

## Recommended Tools
- **Formatter**: `rustfmt`
- **Linter**: `clippy`
- **Testing**: Built-in `cargo test`
- **Package Manager**: `cargo`

---

## Related
- [Best Practices](./best-practices.md)
