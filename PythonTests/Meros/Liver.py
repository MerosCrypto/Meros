#Types.
from typing import Callable, Dict, List, Optional, Any

#Sketch class.
from PythonTests.Libs.Minisketch import Sketch

#Merit classes.
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Merit import Merit

#Element classes.
from PythonTests.Classes.Consensus.Verification import Verification
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket
from PythonTests.Classes.Consensus.MeritRemoval import MeritRemoval

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
class Liver:
    def __init__(
        self,
        rpc: RPC,
        blockchain: List[Dict[str, Any]],
        transactions: Optional[Transactions] = None,
        callbacks: Dict[int, Callable[[], None]] = {},
        everyBlock: Optional[Callable[[int], None]] = None
    ) -> None:
        #RPC.
        self.rpc: RPC = rpc

        #Arguments.
        self.merit: Merit = Merit.fromJSON(blockchain)
        self.transactions: Optional[Transactions] = transactions

        self.callbacks: Dict[int, Callable[[], None]] = dict(callbacks)
        self.everyBlock: Optional[Callable[[int], None]] = everyBlock

    #Sned the DB and verify it.
    def live(
        self
    ) -> None:
        #Handshake with the node.
        self.rpc.meros.liveConnect(self.merit.blockchain.blocks[0].header.hash)
        self.rpc.meros.syncConnect(self.merit.blockchain.blocks[0].header.hash)

        #Send each Block.
        for b in range(1, len(self.merit.blockchain.blocks)):
            #Grab the Block.
            block: Block = self.merit.blockchain.blocks[b]

            #Set loop variables with pending data.
            pendingBody: bool = True
            pendingPackets: List[bytes] = []
            pendingTXs: List[bytes] = []
            for packet in block.body.packets:
                pendingPackets.append(packet.hash)

                if packet.hash not in self.rpc.meros.sentTXs:
                    pendingTXs.append(packet.hash)

            for elem in block.body.elements:
                if isinstance(elem, MeritRemoval):
                    #pylint: disable=consider-merging-isinstance
                    if (
                        (
                            isinstance(elem.e1, Verification) or
                            isinstance(elem.e1, VerificationPacket)
                        ) and
                        (elem.e1.hash not in self.rpc.meros.sentTXs) and
                        (elem.e1.hash not in pendingTXs)
                    ):
                        pendingTXs.append(elem.e1.hash)

                    if (
                        (
                            isinstance(elem.e2, Verification) or
                            isinstance(elem.e2, VerificationPacket)
                        ) and
                        (elem.e2.hash not in self.rpc.meros.sentTXs) and
                        (elem.e2.hash not in pendingTXs)
                    ):
                        pendingTXs.append(elem.e2.hash)

            #Send the Block.
            self.rpc.meros.liveBlockHeader(block.header)

            #Handle sync requests.
            reqHash: bytes = bytes()
            while True:
                #If we sent every bit of data, break.
                if (
                    (not pendingBody) and
                    (not pendingPackets) and
                    (not pendingTXs)
                ):
                    break

                #Receive the next message.
                msg: bytes = self.rpc.meros.sync.recv()

                if MessageType(msg[0]) == MessageType.BlockBodyRequest:
                    #If we already sent the body, raise.
                    if not pendingBody:
                        raise TestError("Meros asked for the same Block Body multiple times.")

                    #Verify Meros asked for the right Block Body.
                    reqHash = msg[1 : 33]
                    if reqHash != block.header.hash:
                        raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

                    #Send the BlockBody.
                    self.rpc.meros.blockBody(block)

                    #Mark the body as sent.
                    pendingBody = False

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

                        #Delete the VerificationPacket from pending.
                        del pendingPackets[pendingPackets.index(packets[sketchHash].hash)]

                    #Make sure Meros asked for every packet.
                    if pendingPackets:
                        raise TestError("Meros didn't ask for every Verification Packet.")

                elif MessageType(msg[0]) == MessageType.TransactionRequest:
                    reqHash = msg[1 : 33]

                    if self.transactions is None:
                        raise TestError("Meros asked for a Transaction when we have none.")

                    if reqHash not in pendingTXs:
                        raise TestError("Meros asked for a non-existent Transaction, a Transaction part of a different Block, or an already sent Transaction.")

                    self.rpc.meros.syncTransaction(self.transactions.txs[reqHash])

                    #Delete the Transaction from pending.
                    del pendingTXs[pendingTXs.index(reqHash)]

                else:
                    raise TestError("Unexpected message sent: " + msg.hex().upper())

            #Receive the BlockHeader from Meros.
            if MessageType(self.rpc.meros.live.recv()[0]) != MessageType.BlockHeader:
                raise TestError("Meros didn't broadcast the new BlockHeader.")

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

        #Reset the node.
        self.rpc.reset()
