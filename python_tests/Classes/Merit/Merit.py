#Types.
from typing import Dict, List, Any

#Transactions classes.
from python_tests.Classes.Transactions.Mint import Mint
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus class.
from python_tests.Classes.Consensus.Consensus import Consensus

#Block, Blockchain, State, and Epochs classes.
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Blockchain import Blockchain
from python_tests.Classes.Merit.State import State
from python_tests.Classes.Merit.Epochs import Epochs

#Merit class.
class Merit:
    #Constructor.
    def __init__(
        self,
        genesis: bytes,
        blockTime: int,
        startDifficulty: int,
        lifetime: int
    ) -> None:
        self.blockchain: Blockchain = Blockchain(
            genesis,
            blockTime,
            startDifficulty
        )
        self.state: State = State(
            lifetime
        )
        self.epochs = Epochs()
        self.mints: List[Mint] = []

    #Add block.
    def add(
        self,
        transactions: Transactions,
        consensus: Consensus,
        block: Block
    ) -> List[Mint]:
        self.blockchain.add(block)

        result: List[Mint] = self.epochs.add(
            transactions,
            consensus,
            self.state,
            block
        )
        self.mints += result

        self.state.add(self.blockchain, block)
        return result

    #Merit -> JSON.
    def toJSON(
        self
    ) -> List[Dict[str, Any]]:
        return self.blockchain.toJSON()

    #JSON -> Merit.
    @staticmethod
    def fromJSON(
        genesis: bytes,
        blockTime: int,
        startDifficulty: int,
        lifetime: int,
        transactions: Transactions,
        consensus: Consensus,
        json: List[Dict[str, Any]]
    ) -> Any:
        result: Merit = Merit(
            bytes(),
            0,
            0,
            0
        )

        result.blockchain = Blockchain.fromJSON(
            genesis,
            blockTime,
            startDifficulty,
            json
        )
        result.state = State(
            lifetime
        )
        result.epochs = Epochs()

        for b in range(1, len(result.blockchain.blocks)):
            mints: List[Mint] = result.epochs.add(
                transactions,
                consensus,
                result.state,
                result.blockchain.blocks[b]
            )
            result.mints += mints

            result.state.add(
                result.blockchain,
                result.blockchain.blocks[b]
            )
        return result
