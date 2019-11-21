#Types.
from typing import Deque, Dict, List, Tuple

#Mint class.
from PythonTests.Classes.Transactions.Mint import Mint

#Block, Blockchain, and State classes.
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain
from PythonTests.Classes.Merit.State import State

#Deque standard lib.
from collections import deque

#Epochs class.
class Epochs:
    #Constructor.
    def __init__(
        self
    ) -> None:
        self.epochs: Deque[Dict[bytes, List[int]]] = deque([{}] * 5)
        self.mint: int = 0

    #Turn scores into rewards.
    def reward(
        self,
        scores: List[Tuple[int, int]]
    ) -> List[Mint]:
        result: List[Mint] = []
        for score in scores:
            if score[1] == 0:
                break

            result.append(Mint(self.mint, (score[0], score[1] * 50)))
            self.mint += 1
        return result

    #Score an Epoch and generate rewards.
    def score(
        self,
        state: State,
        epoch: Dict[bytes, List[int]]
    ) -> List[Mint]:
        #Grab the verified Transactions.
        verified: List[bytes] = []
        for tx in epoch:
            merit: int = 0
            for holder in epoch[tx]:
                merit += state.unlocked[holder]
            if merit >= state.merit // 2 + 1:
                verified.append(tx)

        if not verified:
            return []

        #Assign each Merit Holder 1 point per verified transaction.
        scores: Dict[int, int] = {}
        for tx in verified:
            for holder in epoch[tx]:
                if not holder in scores:
                    scores[holder] = 0
                scores[holder] += 1

        #Multiply each Merit Holder's score by their weight.
        total: int = 0
        tupleScores: List[Tuple[int, int]] = []
        for holder in scores:
            score: int = scores[holder] * state.unlocked[holder]
            total += score
            tupleScores.append((holder, score))

        #Sort the scores and remove trailing scores.
        tupleScores.sort(key=lambda tup: (-tup[1], tup[0]))
        for i in range(100, len(tupleScores)):
            del tupleScores[i]

        #Normalize each score to 1000.
        for i in range(len(tupleScores)):
            tupleScores[i] = (tupleScores[i][0], tupleScores[i][1] * 1000 // total)

        #If we don't have a perfect 1000, fix that.
        total = 0
        for tupleScore in tupleScores:
            total += tupleScore[1]
        tupleScores[0] = (tupleScores[0][0], tupleScores[0][1] + (1000 - total))

        #Create Mints.
        return self.reward(tupleScores)

    #Shift a Block.
    def shift(
        self,
        state: State,
        blockchain: Blockchain,
        b: int
    ) -> List[Mint]:
        #Grab the Block.
        block: Block = blockchain.blocks[b]

        #Construct the new Epoch.
        epoch: Dict[bytes, List[int]] = {}
        for packet in block.body.packets:
            found: bool = False
            for e in range(len(self.epochs)):
                if packet.hash in self.epochs[e]:
                    found = True
                    self.epochs[e][packet.hash] += packet.holders

            if not found:
                if packet.hash not in epoch:
                    epoch[packet.hash] = []
                epoch[packet.hash] += packet.holders

        #Shift on the Epoch.
        self.epochs.append(epoch)
        epoch = self.epochs.popleft()

        return self.score(state, epoch)
