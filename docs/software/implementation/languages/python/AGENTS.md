# Python Coding Guidelines

Python-specific instructions for AI coding agents.

---

## Quick Reference

### Pythonic Code
- ✅ Follow PEP 8 style guide
- ✅ Use `black` for formatting
- ✅ Run `ruff` or `flake8` for linting
- ✅ Use type hints (PEP 484)
- ✅ Prefer list/dict comprehensions over loops (when clear)
- ✅ Use f-strings for formatting

### Type Hints
```python
from typing import List, Dict, Optional

def process_users(users: List[Dict[str, str]]) -> Optional[str]:
    ...
```

### Error Handling
- ✅ Use specific exception types
- ✅ Use `with` for resource management
- ❌ Avoid bare `except:`

### Project Structure
```
project/
├── src/
│   └── mypackage/
│       ├── __init__.py
│       ├── main.py
│       └── utils.py
├── tests/
│   └── test_main.py
├── pyproject.toml
└── README.md
```

---

## Common Pitfalls

### ❌ Mutable Default Arguments
```python
# Bad
def append_to(element, list=[]):
    list.append(element)
    return list

# Good
def append_to(element, list=None):
    if list is None:
        list = []
    list.append(element)
    return list
```

---

## Recommended Tools
- **Formatter**: `black`
- **Linter**: `ruff` or `flake8`
- **Type Checker**: `mypy`
- **Testing**: `pytest`
- **Dependency Management**: `poetry` or `uv`

---

## Related
- [Best Practices](./best-practices.md)
- [Testing](./testing.md)
- [Patterns](./patterns.md)
