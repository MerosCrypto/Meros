#Types.
from typing import Callable, Dict, List, Union, Any

#Sketch class.
from PythonTests.Libs.Minisketch import Sketch

#Merit classes.
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Merit import Merit

#VerificationPacket class.
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

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

#pylint: disable=too-few-public-methods,too-many-statements
class Liver():
    def __init__(
        self,
        rpc: RPC,
        blockchain: List[Dict[str, Any]],
        transactions: Union[Transactions, None] = None,
        callbacks: Dict[int, Callable[[], None]] = {},
        everyBlock: Union[Callable[[int], None], None] = None
    ) -> None:
        #RPC.
        self.rpc: RPC = rpc

        #Arguments.
        self.merit: Merit = Merit.fromJSON(
            b"MEROS_DEVELOPER_NETWORK",
            60,
            int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
            100,
            blockchain
        )
        self.transactions: Union[Transactions, None] = transactions

        self.callbacks: Dict[int, Callable[[], None]] = dict(callbacks)
        self.everyBlock: Union[Callable[[int], None], None] = everyBlock

    #Sned the DB and verify it.
    def live(
        self
    ) -> None:
        #Handshake with the node.
        self.rpc.meros.connect(254, 254, self.merit.blockchain.blocks[0].header.hash)

        #Send each Block.
        for b in range(1, len(self.merit.blockchain.blocks)):
            #Grab the Block.
            block: Block = self.merit.blockchain.blocks[b]

            #Send the Block.
            self.rpc.meros.blockHeader(block.header)

            #Handle sync requests.
            reqHash: bytes = bytes()
            while True:
                msg: bytes = self.rpc.meros.recv()

                if MessageType(msg[0]) == MessageType.Syncing:
                    self.rpc.meros.syncingAcknowledged()

                elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
                    reqHash = msg[1 : 33]
                    if reqHash != block.header.hash:
                        raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

                    #Send the BlockBody.
                    self.rpc.meros.blockBody(self.merit.state.nicks, block)

                elif MessageType(msg[0]) == MessageType.SketchHashesRequest:
                    if not block.body.packets:
                        raise TestError("Meros asked for Sketch Hashes from a Block without any.")

                    reqHash = msg[1 : 33]
                    if reqHash != block.header.hash:
                        raise TestError("Meros asked for Sketch Hashes that didn't belong to the Block we just sent it.")

                    #Create the haashes.
                    hashes: List[int] = []
                    for packet in block.body.packets:
                        hashes.append(Sketch.hash(block.header.sketchSalt, packet))

                    #Send the Sketch Hashes.
                    self.rpc.meros.sketchHashes(hashes)

                elif MessageType(msg[0]) == MessageType.SketchHashRequests:
                    if not block.body.packets:
                        raise TestError("Meros asked for Verification Packets from a Block without any.")

                    reqHash = msg[1 : 33]
                    if reqHash != block.header.hash:
                        raise TestError("Meros asked for Verification Packets that didn't belong to the Block we just sent it.")

                    #Create a lookup of hash to packets.
                    packets: Dict[int, VerificationPacket] = {}
                    for packet in block.body.packets:
                        packets[Sketch.hash(block.header.sketchSalt, packet)] = packet

                    #Look up each requested packet and respond accordingly.
                    for h in range(int.from_bytes(msg[33 : 37], byteorder="big")):
                        sketchHash: int = int.from_bytes(msg[37 + (h * 8) : 45 + (h * 8)], byteorder="big")
                        if sketchHash not in packets:
                            raise TestError("Meros asked for a non-existent Sketch Hash.")
                        self.rpc.meros.packet(packets[sketchHash])

                elif MessageType(msg[0]) == MessageType.TransactionRequest:
                    reqHash = msg[1 : 33]

                    if self.transactions is None:
                        raise TestError("Meros asked for a Transaction when we have none.")

                    if reqHash not in self.transactions.txs:
                        raise TestError("Meros asked for a non-existent Transaction.")

                    self.rpc.meros.transaction(self.transactions.txs[reqHash])

                elif MessageType(msg[0]) == MessageType.SyncingOver:
                    pass

                elif MessageType(msg[0]) == MessageType.BlockHeader:
                    break

                else:
                    raise TestError("Unexpected message sent: " + msg.hex().upper())

            #Add any new nicks to the lookup table.
            if self.merit.blockchain.blocks[b].header.newMiner:
                self.merit.state.nicks.append(self.merit.blockchain.blocks[b].header.minerKey)

            #If there's a callback at this height, call it.
            if b in self.callbacks:
                self.callbacks[b]()

            #Execute the every-Block callback, if it exists.
            if self.everyBlock is not None:
                self.everyBlock(b)

        #Verify the Blockchain.
        verifyBlockchain(self.rpc, self.merit.blockchain)

        #Verify the Transactions.
        if self.transactions is not None:
            verifyTransactions(self.rpc, self.transactions)

        #Reset the RPC.
        self.rpc.reset()
