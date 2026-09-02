# Python test style

Conventions for test bodies. Test docstrings and test class docstrings live in `python-docstring-style.md`.

## Test doubles

Build a real instance of the type for anything that flows *through* the code under test. Reserve `MagicMock` for the edges the test can't or shouldn't reach.

- **Real instance** for values the code under test reads, branches on, or passes along: Pydantic models, dataclasses, ORM rows, enums, plain domain objects.
- **`MagicMock`** for genuine boundaries only:
  - Network and SDK clients (HTTP sessions, cloud SDK resources).
  - The persistence call itself (`Model.get`, `Model.safe_get`, `Model.save`), so the test needs no database.
  - A collaborator whose call order or call arguments are the thing being asserted.

### Why the default is a real instance

A `MagicMock` skips the type's validation, so the test passes on a shape the real constructor would reject. It also answers every attribute with a fresh truthy mock, so a test can assert on a branch the real type makes unreachable. Either way the result is a green test describing behavior that cannot happen in production.

Avoid:

```python
subscription = MagicMock()
subscription.seats = 5
```

Nothing here fails when `Subscription` gains a required field the code under test reads, and `subscription.is_trialing` answers truthy even for a type that has no such attribute.

Prefer:

```python
subscription = Subscription(plan="pro", seats=5)
```

The constructor enforces the real shape, so a drifted model fails in the test rather than in production.

### The usual shape

Patch the persistence boundary, hand it a real instance:

```python
@patch.object(Subscription, "get")
def test_renew_extends_the_paid_through_date(
    self,
    mock_Subscription_get,
) -> None:
    """Ensure renew advances paid_through by one billing period."""
    mock_Subscription_get.return_value = Subscription(plan="pro", seats=5)
```

### When a mock is still right

Reach for `MagicMock` when the real object can't be built cheaply or when the assertion is about the interaction rather than the value:

- The type needs a live connection, a credential, or a container to construct.
- The test asserts call order across a collaborator (`mock.method_calls`), which a real instance doesn't record.
- The double stands in for a third-party client whose real constructor would perform I/O.

Prefer a narrow double over a blanket one: patch the single method at the boundary rather than replacing the whole class, so the rest of the type stays real.
