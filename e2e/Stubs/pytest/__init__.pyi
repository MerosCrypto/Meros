from typing import Type, TypeVar, Generic, Callable, Iterable, Optional, Any

def fixture(
  scope: str = "",
  params: Optional[Iterable[Any]] = None
) -> Callable[..., None]:
  ...

E = TypeVar("E", bound=Exception)
class RaisesContext(
  Generic[E]
):
  ...

  def __enter__(
    self
  ):
    ...

def raises(
  exc: Type[E]
) -> RaisesContext[E]:
  ...
