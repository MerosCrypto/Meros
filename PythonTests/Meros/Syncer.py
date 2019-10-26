#Types.
from typing import Dict, List, Union, Any

#Block and Blockchain classes.
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

#pylint: disable=too-many-instance-attributes
class Syncer():
    def __init__(
        self,
        rpc: RPC,
        blockchain: Blockchain,
        consensus: Union[Consensus, None] = None,
        transactions: Union[Transactions, None] = None,
        settings: Dict[str, Any] = {}
    ) -> None:
        #RPC.
        self.rpc: RPC = rpc

        #DBs/Settings.
        self.blockchain: Blockchain = blockchain
        if consensus is not None:
            self.consensus: Consensus = consensus
        if transactions is not None:
            self.transactions: Transactions = transactions
        self.settings: Dict[str, Any] = dict(settings)

        #Provide default settings.
        if "height" not in self.settings:
            self.settings["height"] = len(self.blockchain.blocks) - 1
        if "playback" not in self.settings:
            self.settings["playback"] = True

        #List of Block hashes in this Blockchain.
        self.blockHashes: Dict[bytes, bool] = {}
        for b in range(self.settings["height"] + 1):
            self.blockHashes[self.blockchain.blocks[b].header.hash] = True

        #List of mentioned Blocks.
        self.blocks: List[Block]

        #Dict of mentioned packets.
        self.packets: Dict[bytes, int] = {}

        #Dict of mentioned Transactions.
        self.txs: Dict[bytes, bool] = {}
        #Dict of synced Transactions.
        self.synced: Dict[bytes, bool] = {}

    #Sync the DB and verify it.
    #The following PyLint error is due to handling all the various message types.
    def sync(
        self
    ) -> None:
        #Handshake with the node.
        self.rpc.meros.connect(254, 254, self.blockchain.blocks[self.settings["height"]].header.hash)

        #Handle sync requests.
        reqHash: bytes = bytes()
        while True:
            msg: bytes = self.rpc.meros.recv()

            if MessageType(msg[0]) == MessageType.Syncing:
                self.rpc.meros.syncingAcknowledged()

            elif MessageType(msg[0]) == MessageType.BlockListRequest:
                if self.blocks != []:
                    raise TestError("Meros is asking for a new BlockList before finishing syncing the last one.")

                for b in range(len(self.blockchain.blocks)):
                    if self.blockchain.blocks[b].header.hash == reqHash:
                        blockList: List[bytes] = []
                        for bl in range(1, msg[2] + 2):
                            if msg[1] == 0:
                                if b - bl < 0:
                                    break
                                self.blocks.append(self.blockchain.blocks[b - bl])
                                blockList.append(self.blocks[-1].header.hash)
                            elif msg[1] == 1:
                                if b + bl > self.settings["height"]:
                                    break
                                self.blocks.append(self.blockchain.blocks[b - bl])
                                blockList.append(self.blocks[-1].header.hash)
                            else:
                                raise TestError("Meros asked for an invalid direction in a BlockListRequest.")
                        self.rpc.meros.blockList(blockList)
                        break

                    if b == self.settings["height"]:
                        self.rpc.meros.dataMissing()

            elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
                if (self.txs != {}) or (self.packets != {}):
                    raise TestError("Meros asked for a new Block before syncing the last Block's Transactions and Packets.")

                reqHash = msg[1 : 49]
                if reqHash != self.blocks[0]:
                    raise TestError("Meros asked for a Block's Header other than the next Block's on the last BlockList.")

                self.rpc.meros.blockHeader(self.blocks[0].header)

            elif MessageType(msg[0]) == MessageType.BlockTransactionsRequest:
                reqHash = msg[1 : 49]
                if reqHash != self.blocks[0]:
                    raise TestError("Meros asked for a Block's Transactions other than the next Block on the last BlockList.")

                txs: List[bytes] = []
                for packet in self.blocks[0].body.packets:
                    txs.append(packet.hash)
                    if packet.hash not in self.synced:
                        self.packets[packet.hash] = True
                        self.txs[packet.hash] = True
                self.rpc.meros.blockTransactions(txs)

                del self.blockHashes[reqHash]

            elif MessageType(msg[0]) == MessageType.VerificationPacketRequest:
                reqHash = msg[1 : 49]
                if reqHash != self.blocks[0]:
                    raise TestError("Meros asked for a Block's VerificationPacket other than the next Block on the last BlockList.")

                reqHash = msg[49 : 97]
                for packet in self.blocks[0].body.packets:
                    if packet.hash == reqHash:
                        self.rpc.meros.packet(packet)
                        del self.packets[reqHash]
                        break

                    if packet.hash == self.blocks[0].body.packets[len(self.blocks[0].body.packets) - 1].hash:
                        raise TestError("Meros asked for a VerificationPacket for a Transaction in a Block which doesn't have that Transaction.")

                if self.packets == {}:
                    del self.blocks[0]

            elif MessageType(msg[0]) == MessageType.TransactionRequest:
                reqHash = msg[1 : 49]

                if self.transactions is None:
                    raise TestError("Meros asked for a Transaction when we have none.")

                if reqHash not in self.transactions.txs:
                    raise TestError("Meros asked for a Transaction we don't have.")

                if reqHash not in self.txs:
                    raise TestError("Meros asked for a Transaction we haven't mentioned.")

                self.rpc.meros.transaction(self.transactions.txs[reqHash])
                self.synced[reqHash] = True
                del self.txs[reqHash]

            elif MessageType(msg[0]) == MessageType.SyncingOver:
                #Break out of the for loop if the sync finished.
                #This means we sent every Block, every Element, every Transaction...
                if (
                    (self.blockHashes == {}) and
                    (self.packets == {}) and
                    (self.txs == {})
                ):
                    break

            else:
                raise TestError("Unexpected message sent: " + msg.hex().upper())

        #Verify the Blockchain.
        verifyBlockchain(self.rpc, self.blockchain)

        """
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
        """

        if self.settings["playback"]:
            #Playback their messages.
            self.rpc.meros.playback()
