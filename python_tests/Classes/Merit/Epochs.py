#Types.
from typing import Dict, List, Tuple

#Mint and Transactions classes.
from python_tests.Classes.Transactions.Mint import Mint
from python_tests.Classes.Transactions.Transactions import Transactions

#Verification Consensus classes.
from python_tests.Classes.Consensus.Verification import Verification
from python_tests.Classes.Consensus.Consensus import Consensus

#Block and State classes.
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.State import State

#BLS lib.
import blspy

#Epochs class.
class Epochs:
    #Constructor.
    def __init__(
        self
    ) -> None:
        self.tips: Dict[bytes, int] = {}
        self.epochs: List[Dict[bytes, List[bytes]]] = [
            {},
            {},
            {},
            {},
            {}
        ]
        self.mint: int = 0

    #Add block.
    def add(
        self,
        transactions: Transactions,
        consensus: Consensus,
        state: State,
        block: Block
    ) -> List[Mint]:
        #Construct the new Epoch.
        epoch: Dict[bytes, List[bytes]] = {}
        for record in block.body.records:
            mh: bytes = record[0].serialize()
            start = 0
            if mh in self.tips:
                start = self.tips[mh]
            self.tips[mh] = record[1]

            for e in range(start, record[1] + 1):
                if isinstance(consensus.holders[mh][e], Verification):
                    tx: bytes = Verification.fromElement(consensus.holders[mh][e]).hash
                    if not tx in epoch:
                        epoch[tx] = []
                    epoch[tx].append(mh)

        #Move TXs belonging to an old Epoch to said Epoch.
        txs: List[bytes] = list(epoch.keys())
        for tx in txs:
            for e in range(5):
                if tx in self.epochs[e]:
                    self.epochs[e][tx] += epoch[tx]
                    del epoch[tx]

        #Grab the oldest Epoch.
        self.epochs.append(epoch)
        epoch = self.epochs[0]
        del self.epochs[0]

        #Grab the verified transactions.
        verified: List[bytes] = []
        for tx in epoch:
            if transactions.txs[tx].verified:
                verified.append(tx)

        if len(verified) == 0:
            return []

        #Assign each Merit Holder 1 point per verified transaction.
        scores: Dict[bytes, int] = {}
        for tx in verified:
            for holder in epoch[tx]:
                if not holder in scores:
                    scores[holder] = 0
                scores[holder] += 1

        #Multiply each Merit Holder's score by their weight.
        total: int = 0
        tupleScores: List[Tuple[bytes, int]] = []
        for holder in scores:
            score: int = scores[holder] * state.live[holder]
            total += score
            tupleScores.append((holder, score))

        #Sort the scores and remove trailing scores.
        tupleScores.sort(key = lambda tup: (tup[1], int.from_bytes(tup[0], byteorder = "big")), reverse=True)
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
        result: List[Mint] = []
        for final in tupleScores:
            if final[1] == 0:
                continue

            result.append(Mint(
                self.mint,
                (
                    blspy.PublicKey.from_bytes(final[0]),
                    final[1] * 50
                )
            ))
        return result
