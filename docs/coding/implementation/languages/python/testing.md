# Python Testing

Testing with pytest.

---

## Basic Test

```python
def test_add():
    assert add(2, 3) == 5
```

---

## Fixtures

```python
import pytest

@pytest.fixture
def user():
    return User(id="123", name="Test")

def test_user(user):
    assert user.name == "Test"
```

---

## Parametrize

```python
@pytest.mark.parametrize("a,b,expected", [
    (2, 3, 5),
    (0, 0, 0),
    (-1, 1, 0),
])
def test_add(a, b, expected):
    assert add(a, b) == expected
```
