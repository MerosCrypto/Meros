#Types.
from typing import Dict, List, Union, Any

#Sketch class.
from PythonTests.Classes.Merit.Minisketch import Sketch

#Block and Blockchain classes.
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Transactions class.
from PythonTests.Classes.Transactions.Transactions import Transactions

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#Merit and Transactions verifiers.
from PythonTests.Tests.Merit.Verify import verifyBlockchain
from PythonTests.Tests.Transactions.Verify import verifyTransactions

#pylint: disable=too-many-instance-attributes,too-few-public-methods
class Syncer():
    def __init__(
        self,
        rpc: RPC,
        blockchain: Blockchain,
        transactions: Union[Transactions, None] = None,
        settings: Dict[str, Any] = {}
    ) -> None:
        #RPC.
        self.rpc: RPC = rpc

        #DBs/Settings.
        self.blockchain: Blockchain = blockchain
        self.transactions: Union[Transactions, None] = transactions
        self.settings: Dict[str, Any] = dict(settings)

        #Provide default settings.
        if "height" not in self.settings:
            self.settings["height"] = len(self.blockchain.blocks) - 1
        if "playback" not in self.settings:
            self.settings["playback"] = True

        #List of Block hashes in this Blockchain.
        self.blockHashes: Dict[bytes, bool] = {}
        for b in range(1, self.settings["height"] + 1):
            self.blockHashes[self.blockchain.blocks[b].header.blockHash] = True

        #List of mentioned Blocks.
        self.blocks: List[Block] = [self.blockchain.blocks[self.settings["height"]]]

        #Dict of mentioned packets.
        self.packets: Dict[bytes, int] = {}

        #Dict of mentioned Transactions.
        self.txs: Dict[bytes, bool] = {}
        #Dict of synced Transactions.
        self.synced: Dict[bytes, bool] = {}

    #Sync the DB and verify it.
    #The following PyLint errors are due to handling all the various message types.
    #pylint: disable=too-many-nested-blocks,too-many-statements
    def sync(
        self
    ) -> None:
        #Handshake with the node.
        self.rpc.meros.connect(254, 254, self.blockchain.blocks[self.settings["height"]].header.blockHash)

        #Handle sync requests.
        reqHash: bytes = bytes()
        while True:
            msg: bytes = self.rpc.meros.recv()

            if MessageType(msg[0]) == MessageType.Syncing:
                self.rpc.meros.syncingAcknowledged()

            elif MessageType(msg[0]) == MessageType.BlockListRequest:
                for b in range(len(self.blockchain.blocks)):
                    if self.blockchain.blocks[b].header.blockHash == reqHash:
                        blockList: List[bytes] = []
                        for bl in range(1, msg[2] + 2):
                            if msg[1] == 0:
                                if b - bl < 0:
                                    break

                                blockList.append(self.blockchain.blocks[b - bl].header.blockHash)
                                if b - bl != 0:
                                    self.blocks.append(self.blockchain.blocks[b - bl])

                            elif msg[1] == 1:
                                if b + bl > self.settings["height"]:
                                    break

                                blockList.append(self.blockchain.blocks[b + bl].header.blockHash)
                                self.blocks.append(self.blockchain.blocks[b + bl])

                            else:
                                raise TestError("Meros asked for an invalid direction in a BlockListRequest.")

                        if blockList == []:
                            self.rpc.meros.dataMissing()
                            break

                        self.rpc.meros.blockList(blockList)
                        break

                    if b == self.settings["height"]:
                        self.rpc.meros.dataMissing()

            elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
                if (self.txs != {}) or (self.packets != {}):
                    raise TestError("Meros asked for a new Block before syncing the last Block's Transactions and Packets.")

                reqHash = msg[1 : 49]
                if reqHash != self.blocks[-1].header.blockHash:
                    raise TestError("Meros asked for a BlockHeader other than the next Block's on the last BlockList.")

                self.rpc.meros.blockHeader(self.blocks[-1].header)

            elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
                reqHash = msg[1 : 49]
                if reqHash != self.blocks[-1].header.blockHash:
                    raise TestError("Meros asked for a BlockBody other than the next Block's on the last BlockList.")

                self.rpc.meros.blockBody(self.blocks[-1])
                del self.blockHashes[reqHash]

                #Set packets/transactions.

                if self.packets == {}:
                    del self.blocks[-1]

            elif MessageType(msg[0]) == MessageType.SketchHashesRequest:
                reqHash = msg[1 : 49]
                if reqHash != self.blocks[-1].header.blockHash:
                    raise TestError("Meros asked for Sketch Hashes that didn't belong to the header we just sent it.")

                #Create the haashes.
                hashes: List[int] = []
                for packet in self.blocks[-1].body.packets:
                    hashes.append(Sketch.hash(self.blocks[-1].header.sketchSalt, packet))

                #Send the Sketch Hashes.
                self.rpc.meros.sketchHashes(hashes)

            elif MessageType(msg[0]) == MessageType.SketchHashRequests:
                raise TestError("SketchHashRequests")

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

        #Verify the Transactions.
        if self.transactions is not None:
            verifyTransactions(self.rpc, self.transactions)

        if self.settings["playback"]:
            #Playback their messages.
            self.rpc.meros.playback()
