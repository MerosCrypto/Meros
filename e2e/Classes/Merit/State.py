from typing import Dict, List

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

#pylint: disable=too-few-public-methods
class State:
  def __init__(
    self
  ) -> None:
    self.lifetime: int = 100
    self.merit = 0
    self.nicks: List[bytes] = []
    self.unlocked: Dict[int, int] = {}

  def add(
    self,
    blockchain: Blockchain,
    b: int
  ) -> None:
    block: Block = blockchain.blocks[b]

    miner: int
    if block.header.newMiner:
      miner = len(self.nicks)
      self.nicks.append(block.header.minerKey)
      self.unlocked[miner] = 0
    else:
      miner = block.header.minerNick
    self.unlocked[miner] += 1
    self.merit += 1

    if b > self.lifetime:
      oldHeader: BlockHeader = blockchain.blocks[b - self.lifetime].header
      if oldHeader.newMiner:
        miner = blockchain.keys[oldHeader.minerKey]
      else:
        miner = oldHeader.minerNick
      self.unlocked[miner] -= 1
      self.merit -= 1
