#Types.
from typing import Dict, List

#Block and Blockchain classes.
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Blockchain import Blockchain

#Currently, Meros says all Merit is always live.
alwaysLive: bool = True

#State class.
class State:
    #Constructor.
    def __init__(
        self,
        lifetime: int
    ) -> None:
        self.lifetime: int = lifetime

        self.merit = 0
        self.live: Dict[bytes, int] = {}
        self.dead: Dict[bytes, int] = {}
        self.mentioned: Dict[bytes, bool] = {}
        self.pending: List[bytes] = []

    #Add block.
    def add(
        self,
        blockchain: Blockchain,
        block: Block
    ) -> None:
        for minerTuple in block.body.miners:
            miner: bytes = minerTuple[0].serialize()
            if miner in self.live:
                self.live[miner] += minerTuple[1]
                self.merit += minerTuple[1]
            elif miner in self.dead:
                self.dead[miner] += minerTuple[1]
            else:
                self.live[miner] = minerTuple[1]
                self.merit += minerTuple[1]
                self.mentioned[miner] = True

        if block.header.nonce > self.lifetime:
            for minerTuple in blockchain.blocks[block.header.nonce - self.lifetime].body.miners:
                miner = minerTuple[0].serialize()
                if miner in self.live:
                    self.live[miner] -= minerTuple[1]
                    self.merit -= minerTuple[1]
                else:
                    self.dead[miner] -= minerTuple[1]

        if not alwaysLive:
            for record in block.body.records:
                miner = record[0].serialize()
                if miner in self.live:
                    self.mentioned[miner] = True
                else:
                    self.pending.append(miner)

            if block.header.nonce % 5 == 0:
                for miner in self.live:
                    if not miner in self.mentioned:
                        self.dead[miner] = self.live[miner]
                        del self.live[miner]
                        self.merit -= self.live[miner]
                self.mentioned = {}

            for miner in self.pending:
                self.live[miner] = self.dead[miner]
                del self.dead[miner]
                self.merit += self.live[miner]
            self.pending = []
