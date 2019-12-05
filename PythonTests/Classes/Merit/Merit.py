#Types.
from typing import Dict, List, Optional, Any

#Mint class.
from PythonTests.Classes.Transactions.Mint import Mint

#Block, Blockchain, State, and Epochs classes.
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain
from PythonTests.Classes.Merit.State import State
from PythonTests.Classes.Merit.Epochs import Epochs

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
        self.state: State = State(lifetime)
        self.epochs = Epochs()
        self.mints: List[Mint] = []

    #Add block.
    def add(
        self,
        block: Block
    ):
        self.blockchain.add(block)

        mint: Optional[Mint] = self.epochs.shift(
            self.state,
            self.blockchain,
            len(self.blockchain.blocks) - 1
        )
        if mint is not None:
            self.mints.append(mint)

        self.state.add(self.blockchain, len(self.blockchain.blocks) - 1)

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
        json: List[Dict[str, Any]]
    ) -> Any:
        result: Merit = Merit.__new__(Merit)

        result.blockchain = Blockchain.fromJSON(
            genesis,
            blockTime,
            startDifficulty,
            json
        )
        result.state = State(lifetime)
        result.epochs = Epochs()
        result.mints = []

        for b in range(1, len(result.blockchain.blocks)):
            result.mints += result.epochs.shift(
                result.state,
                result.blockchain,
                b
            )

            result.state.add(result.blockchain, b)
        return result
