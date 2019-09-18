#Types.
from typing import Callable, Dict, Union

#Blockchain classes.
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Consensus classes.
from PythonTests.Classes.Consensus.Element import Element
from PythonTests.Classes.Consensus.Verification import Verification
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
from PythonTests.Tests.Consensus.Verify import verifyConsensus
from PythonTests.Tests.Transactions.Verify import verifyTransactions

#pylint: disable=too-few-public-methods,too-many-instance-attributes
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
        if consensus is not None:
            self.consensus: Consensus = consensus
        if transactions is not None:
            self.transactions: Transactions = transactions

        self.callbacks: Dict[int, Callable[[], None]] = dict(callbacks)
        self.everyBlock: Union[Callable[[int], None], None] = everyBlock

        #Complete set of newest tips.
        self.allTips: Dict[bytes, int] = {}
        #Synced Transactionss.
        self.syncedTXs: Dict[bytes, bool] = {}

    #Sned the DB and verify it.
    def live(
        self
    ) -> None:
        #Handshake with the node.
        self.rpc.meros.connect(254, 254, 1)

        #Send each Block.
        for b in range(1, len(self.blockchain.blocks)):
            #Grab the Block.
            block: Block = self.blockchain.blocks[b]
            #Grab the tips.
            tips: Dict[bytes, int] = {}
            for tip in block.body.records:
                tips[tip[0].serialize()] = tip[1]
            #See what TXs were mentiooed.
            txs: Dict[bytes, bool] = {}
            for tipHolder in tips:
                for e in range(
                    self.allTips[tipHolder] + 1 if tipHolder in self.allTips else 0,
                    tips[tipHolder] + 1
                ):
                    elem: Element = self.consensus.holders[tipHolder][e]
                    if isinstance(elem, Verification):
                        if Verification.fromElement(elem).hash not in self.syncedTXs:
                            txs[Verification.fromElement(elem).hash] = True

            #Send the Block.
            self.rpc.meros.blockHeader(block.header)

            #Handle sync requests.
            reqHash: bytes = bytes()
            while True:
                msg: bytes = self.rpc.meros.recv()

                if MessageType(msg[0]) == MessageType.Syncing:
                    self.rpc.meros.acknowledgeSyncing()

                elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
                    reqHash = msg[1 : 49]
                    if reqHash != block.header.hash:
                        raise TestError("Meros asked for a Block Body that didn't belong to the header we just sent it.")

                    #Send the BlockBody.
                    self.rpc.meros.blockBody(block.body)

                elif MessageType(msg[0]) == MessageType.ElementRequest:
                    holder: bytes = msg[1 : 49]
                    nonce: int = int.from_bytes(msg[49 : 53], "big")

                    if self.consensus is None:
                        raise TestError("Meros asked for an Element when we have none.")

                    if holder not in self.consensus.holders:
                        raise TestError("Meros asked for an Element from a holder we don't have.")

                    if nonce >= len(self.consensus.holders[holder]):
                        raise TestError("Meros asked for an Element we don't have.")

                    if holder not in tips:
                        raise TestError("Meros asked for an Element from a holder who hasn't had their record updated.")

                    if tips[holder] == nonce:
                        del tips[holder]

                    self.rpc.meros.element(self.consensus.holders[holder][nonce])

                elif MessageType(msg[0]) == MessageType.TransactionRequest:
                    reqHash = msg[1 : 49]

                    if self.transactions is None:
                        raise TestError("Meros asked for a Transaction when we have none.")

                    if reqHash not in self.transactions.txs:
                        raise TestError("Meros asked for a Transaction we don't have.")

                    if reqHash not in txs:
                        raise TestError("Meros asked for Transaction which hasn't been mentioned/was already synced.")
                    del txs[reqHash]

                    self.rpc.meros.transaction(self.transactions.txs[reqHash])

                elif MessageType(msg[0]) == MessageType.SyncingOver:
                    #Break out of the foor loop if the sync finished.
                    #This means we sent every Element and every Transaction.
                    if (tips == {}) and (txs == {}):
                        #Update self.allTips with this Block's tips.
                        for tip in block.body.records:
                            self.allTips[tip[0].serialize()] = tip[1]
                        break

                elif MessageType(msg[0]) == MessageType.BlockHeader:
                    pass

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
        try:
            verifyConsensus(self.rpc, self.consensus)
        except AttributeError:
            pass

        #Verify the Transactions.
        try:
            verifyTransactions(self.rpc, self.transactions)
        except AttributeError:
            pass
