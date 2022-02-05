from typing import Iterable, Union, List, Tuple

def encode(
  hrp: str,
  version: int,
  data: Iterable[int]
) -> str:
  ...

def decode(
  hrp: str,
  address: str
) -> Union[Tuple[None, None], Tuple[int, List[int]]]:
  ...
