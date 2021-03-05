from typing import Dict, List, Any

from e2e.Libs.RandomX import setRandomXKey
from e2e.Libs.BLS import PublicKey

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block

class Blockchain:
  def __init__(
    self
  ) -> None:
    self.genesis: bytes = b"MEROS_DEVELOPER_NETWORK".ljust(32, b'\0')

    self.upcomingKey: bytes = self.genesis
    setRandomXKey(self.upcomingKey)

    self.blockTime: int = 60
    self.difficulties: List[int] = [100]
    self.keys: Dict[bytes, int] = {}

    self.blocks: List[Block] = [
      Block(
        BlockHeader(
          0,
          self.genesis,
          bytes(32),
          0,
          bytes(4),
          bytes(32),
          PublicKey().serialize(),
          0
        ),
        BlockBody()
      )
    ]

  def __eq__(
    self,
    other
  ) -> bool:
    return isinstance(other, self.__class__) and other.toJSON() == self.toJSON()
  
  def __ne__(
    self,
    other
  ) -> bool:
    if isinstance(other, self.__class__):
      return self.toJSON() != other.toJSON()
    return True

  def add(
    self,
    block: Block
  ) -> None:
    self.blocks.append(block)

    if len(self.blocks) % 384 == 0:
      self.upcomingKey = block.header.hash
    elif len(self.blocks) % 384 == 12:
      setRandomXKey(self.upcomingKey)

    if len(self.blocks) < 6:
      self.difficulties.append(self.difficulties[0])
    else:
      windowLength: int = 72
      if len(self.blocks) < 4320:
        windowLength = 5
      elif len(self.blocks) < 12960:
        windowLength = 9
      elif len(self.blocks) < 25920:
        windowLength = 18
      elif len(self.blocks) < 52560:
        windowLength = 36

      window: List[Block] = self.blocks[len(self.blocks) - windowLength : len(self.blocks)]
      windowDifficulties: List[int] = self.difficulties[len(self.difficulties) - (windowLength - 1) : len(self.difficulties)]
      windowDifficulties.sort()

      median: int = windowDifficulties[len(windowDifficulties) // 2]
      for _ in range(len(windowDifficulties) // 10):
        if (median - windowDifficulties[0]) > (windowDifficulties[-1] - median):
          del windowDifficulties[0]
        elif (median - windowDifficulties[0]) == (windowDifficulties[-1] - median):
          del windowDifficulties[0]
        elif (median - windowDifficulties[0]) < (windowDifficulties[-1] - median):
          del windowDifficulties[-1]

      self.difficulties.append(
        max(sum(windowDifficulties) * 60 // (window[-1].header.time - window[0].header.time), 1)
      )
      if block.header.newMiner:
        self.difficulties[-1] = self.difficulties[-1] * 11 // 10

    if block.header.newMiner:
      self.keys[block.header.minerKey] = len(self.keys)

  def last(
    self
  ) -> bytes:
    return self.blocks[len(self.blocks) - 1].header.hash

  def difficulty(
    self
  ) -> int:
    return self.difficulties[-1]

  def toJSON(
    self
  ) -> List[Dict[str, Any]]:
    result: List[Dict[str, Any]] = []
    for b in range(1, len(self.blocks)):
      result.append(self.blocks[b].toJSON())
    return result

  @staticmethod
  def fromJSON(
    blocks: List[Dict[str, Any]]
  ) -> Any:
    result = Blockchain()
    for block in blocks:
      result.add(Block.fromJSON(block))
    return result
