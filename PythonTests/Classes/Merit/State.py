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
        self,
        lifetime: int
    ) -> None:
        self.lifetime: int = lifetime

        self.merit = 0
        self.nicks: List[bytes] = []
        self.keys: Dict[bytes, int] = {}
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
            self.keys[block.header.minerKey] = miner
            self.unlocked[miner] = 0
        else:
            miner = block.header.minerNick
        self.unlocked[miner] += 1
        self.merit += 1

        if b > self.lifetime:
            oldHeader: BlockHeader = blockchain.blocks[b - self.lifetime].header
            if oldHeader.newMiner:
                miner = self.keys[oldHeader.minerKey]
            else:
                miner = oldHeader.minerNick
            self.unlocked[miner] -= 1
            self.merit -= 1
