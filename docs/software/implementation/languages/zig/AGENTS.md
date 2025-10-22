# Zig Coding Guidelines

Zig-specific instructions for AI coding agents.

---

## Quick Reference

### Memory Management
- ✅ Explicit allocation with allocators
- ✅ No hidden control flow
- ✅ Manual memory management (no GC)

### Error Handling
- ✅ Use error unions: `!T`
- ✅ Use `try` for error propagation
- ✅ Use `catch` for error handling

### Comptime
- ✅ Leverage compile-time execution
- ✅ Use comptime for metaprogramming

---

## Recommended Tools
- **Build**: `zig build`
- **Testing**: `zig test`
- **Formatter**: `zig fmt`

---

## Related
- [Best Practices](./best-practices.md)
