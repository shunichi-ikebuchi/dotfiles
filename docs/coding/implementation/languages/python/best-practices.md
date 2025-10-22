# Python Best Practices

---

## Type Hints

```python
from typing import List, Dict, Optional, Union

def get_user(user_id: str) -> Optional[Dict[str, str]]:
    ...
```

---

## List Comprehensions

```python
# Good
squares = [x**2 for x in range(10)]
evens = [x for x in range(10) if x % 2 == 0]
```

---

## Context Managers

```python
with open('file.txt') as f:
    data = f.read()
```

---

## Dataclasses

```python
from dataclasses import dataclass

@dataclass
class User:
    id: str
    name: str
    email: str
```

---

## Related
- [Testing](./testing.md)
- [Patterns](./patterns.md)
