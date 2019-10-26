#Types.
from typing import Callable, Dict, Union

#Blockchain classes.
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Consensus class.
from PythonTests.Classes.Consensus.Consensus import Consensus

#Transactions class.
from PythonTests.Classes.Transactions.Transactions import Transactions

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#Merit, Consensus, and Transactions verifiers.
from PythonTests.Tests.Merit.Verify import verifyBlockchain
"""
from PythonTests.Tests.Consensus.Verify import verifyConsensus
from PythonTests.Tests.Transactions.Verify import verifyTransactions
"""

#pylint: disable=too-few-public-methods
class Liver():
    def __init__(
        self,
        rpc: RPC,
        blockchain: Blockchain,
        consensus: Union[Consensus, None] = None,
        transactions: Union[Transactions, None] = None,
        callbacks: Dict[int, Callable[[], None]] = {},
        everyBlock: Union[Callable[[int], None], None] = None
    ) -> None:
        #RPC.
        self.rpc: RPC = rpc

        #Arguments.
        self.blockchain: Blockchain = blockchain
        self.consensus: Union[Consensus, None] = consensus
        self.transactions: Union[Transactions, None] = transactions

        self.callbacks: Dict[int, Callable[[], None]] = dict(callbacks)
        self.everyBlock: Union[Callable[[int], None], None] = everyBlock

    #Sned the DB and verify it.
    def live(
        self
    ) -> None:
        #Handshake with the node.
        self.rpc.meros.connect(254, 254, self.blockchain.blocks[0].header.hash)

        #Send each Block.
        for b in range(1, len(self.blockchain.blocks)):
            #Grab the Block.
            block: Block = self.blockchain.blocks[b]

            #Send the Block.
            self.rpc.meros.blockHeader(block.header)

            #Handle sync requests.
            reqHash: bytes = bytes()
            while True:
                msg: bytes = self.rpc.meros.recv()

                if MessageType(msg[0]) == MessageType.Syncing:
                    self.rpc.meros.syncingAcknowledged()

                elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
                    reqHash = msg[1 : 49]
                    if reqHash != block.header.hash:
                        raise TestError("Meros asked for a Block Body that didn't belong to the header we just sent it.")

                    #Send the BlockBody.
                    self.rpc.meros.blockBody(block.body)

                elif MessageType(msg[0]) == MessageType.TransactionRequest:
                    reqHash = msg[1 : 49]

                    if self.transactions is None:
                        raise TestError("Meros asked for a Transaction when we have none.")

                    if reqHash not in self.transactions.txs:
                        raise TestError("Meros asked for a Transaction we don't have.")

                    self.rpc.meros.transaction(self.transactions.txs[reqHash])

                elif MessageType(msg[0]) == MessageType.SyncingOver:
                    pass

                elif MessageType(msg[0]) == MessageType.BlockHeader:
                    break

                else:
                    raise TestError("Unexpected message sent: " + msg.hex().upper())

            #If there's a callback at this height, call it.
            if b in self.callbacks:
                self.callbacks[b]()

            #Execute the every-Block callback, if it exists.
            if self.everyBlock is not None:
                self.everyBlock(b)

        #Verify the Blockchain.
        verifyBlockchain(self.rpc, self.blockchain)

        #Verify the Consensus.
        if self.consensus is not None:
            """
            verifyConsensus(self.rpc, self.consensus)
            """

        #Verify the Transactions.
        if self.transactions is not None:
            """
            verifyTransactions(self.rpc, self.transactions)
            """

        #Reset the RPC.
        self.rpc.reset()
