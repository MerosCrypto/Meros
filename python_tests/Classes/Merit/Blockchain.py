#Types.
from typing import Dict, List, Any

#BlockHeader, BlockBody, and Block classes.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody
from python_tests.Classes.Merit.Block import Block

#Blockchain class.
class Blockchain:
    #Constructor.
    def __init__(
        self,
        genesis: bytes,
        blockTime: int,
        startDifficulty: int
    ) -> None:
        self.blockTime: int = blockTime

        self.startDifficulty: int = startDifficulty
        self.maxDifficulty: int = (2 ** 384) - 1
        self.difficulty: int = startDifficulty
        self.difficultyUntil: int = 1

        self.blocks: List[Block] = [
            Block(
                BlockHeader(
                    0,
                    genesis.rjust(48, b'\0'),
                    0
                ),
                BlockBody(
                    miners = []
                )
            )
        ]

    #Add block.
    def add(
        self,
        block: Block
    ) -> None:
        self.blocks.append(block)

        if block.header.nonce == self.difficultyUntil:
            #Blocks per months.
            blocksPerMonth: int = 2592000 // self.blockTime
            #Blocks per difficulty period.
            blocksPerPeriod: int = 0
            #If we're in the first month, the period length is one block.
            if block.header.nonce + 1 < blocksPerMonth:
                blocksPerPeriod = 1
            #If we're in the first three months, the period length is one hour.
            elif block.header.nonce + 1 < blocksPerMonth * 3:
                blocksPerPeriod = 6
            #If we're in the first six months, the period length is six hours.
            elif block.header.nonce + 1 < blocksPerMonth * 6:
                blocksPerPeriod = 36
            #If we're in the first year, the period length is twelve hours.
            elif block.header.nonce + 1 < blocksPerMonth * 12:
                blocksPerPeriod = 72
            #Else, if it's over an year, the period length is a day.
            else:
                blocksPerPeriod = 144
            self.difficultyUntil += blocksPerPeriod

            #Last difficulty.
            last: int = self.difficulty
            #Target time.
            targetTime: int = self.blockTime * blocksPerPeriod
            #Period time.
            periodTime: int = block.header.time - self.blocks[block.header.nonce - blocksPerPeriod].header.time

            #Possible values.
            possible: int = self.maxDifficulty - self.difficulty
            #Change.
            change: int = 0
            #New difficulty.
            difficulty: int = 0

            #If we went faster...
            if periodTime < targetTime:
                #Set the change to be:
                    #The possible values multipled by
                        #The targetTime (bigger) minus the periodTime (smaller)
                        #Over the targetTime
                #Since we need the difficulty to increase.
                change = (possible * (targetTime - periodTime)) // targetTime

                #If we're increasing the difficulty by more than 10%...
                if possible // 10 < change:
                    #Set the change to be 10%.
                    change = possible // 10

                #Set the difficulty.
                difficulty = last + change
            #If we went slower...
            elif periodTime > targetTime:
                #Set the change to be:
                    #The invalid values
                    #Multipled by the targetTime (smaller)
                    #Divided by the periodTime (bigger)
                #Since we need the difficulty to decrease.
                change = last * (targetTime // periodTime)

                #If we're decreasing the difficulty by more than 10% of the possible values...
                if possible // 10 < change:
                    #Set the change to be 10% of the possible values.
                    change = possible // 10

                #Set the difficulty.
                difficulty = last - change

            #If the difficulty is lower than the starting difficulty, use that.
            if difficulty < self.startDifficulty:
                difficulty = self.startDifficulty

            #Set the new difficulty.
            self.difficulty = difficulty

    #Last hash.
    def last(
        self
    ) -> bytes:
        return self.blocks[len(self.blocks) - 1].header.hash

    #Blockchain -> JSON.
    def toJSON(
        self
    ) -> List[Dict[str, Any]]:
        result: List[Dict[str, Any]] = []
        for b in range(1, len(self.blocks)):
            result.append(self.blocks[b].toJSON())
        return result

    #JSON -> Blockchain.
    @staticmethod
    def fromJSON(
        genesis: bytes,
        blockTime: int,
        startDifficulty: int,
        blocks: List[Dict[str, Any]]
    ) -> Any:
        result = Blockchain(
            genesis,
            blockTime,
            startDifficulty
        )
        for block in blocks:
            result.add(Block.fromJSON(block))
        return result
