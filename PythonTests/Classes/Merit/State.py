#Types.
from typing import Dict, List

#BlockHeader, Block, and Blockchain classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#State class.
#pylint: disable=too-few-public-methods
class State:
  #Constructor.
  def __init__(
    self
  ) -> None:
    self.lifetime: int = 100

    self.merit = 0
    self.nicks: List[bytes] = []
    self.unlocked: Dict[int, int] = {}

  #Add block.
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
