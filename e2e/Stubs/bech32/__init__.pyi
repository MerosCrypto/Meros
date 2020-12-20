from typing import Iterable, Union, List, Tuple

CHARSET: str = ...

#This is actually Option[List[int]]. That said, if the bits arguments are proper, this is never trigerred.
#It's also a poor API in the first place, and fudging the type hints helps out.
def convertbits(
  data: Iterable[int],
  frombits: int,
  tobits: int,
  pad: bool = ...
) -> List[int]:
  ...

def bech32_encode(
  hrp: str,
  data: Iterable[int]
) -> str:
  ...

def bech32_decode(
  bech: str
) -> Union[Tuple[None, None], Tuple[str, List[int]]]:
  ...
