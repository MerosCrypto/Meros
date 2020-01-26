#Types.
from typing import Dict, List, Tuple, Any

#Transactions classes.
from PythonTests.Classes.Transactions.Transaction import Transaction
from PythonTests.Classes.Transactions.Claim import Claim
from PythonTests.Classes.Transactions.Send import Send
from PythonTests.Classes.Transactions.Data import Data

#Consensus classes.
from PythonTests.Classes.Consensus.Element import SignedElement
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket
from PythonTests.Classes.Consensus.SendDifficulty import SignedSendDifficulty
from PythonTests.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from PythonTests.Classes.Consensus.MeritRemoval import PartialMeritRemoval

#Merit classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.Block import Block

#NodeError and TestError Exceptions.
from PythonTests.Tests.Errors import NodeError, TestError

#Enum class.
from enum import Enum

#Subprocess class.
from subprocess import Popen

#Socket standard lib.
import socket

#Message Types.
class MessageType(
    Enum
):
    Handshake                 = 0
    BlockchainTail            = 1

    Syncing                   = 2
    SyncingAcknowledged       = 3
    PeersRequest              = 4
    Peers                     = 5
    BlockListRequest          = 6
    BlockList                 = 7

    BlockHeaderRequest        = 9
    BlockBodyRequest          = 10
    SketchHashesRequest       = 11
    SketchHashRequests        = 12
    TransactionRequest        = 13
    DataMissing               = 14
    SyncingOver               = 15

    Claim                     = 16
    Send                      = 17
    Data                      = 18

    SignedVerification        = 21
    SignedSendDifficulty      = 22
    SignedDataDifficulty      = 23
    SignedMeritRemoval        = 25

    BlockHeader               = 27
    BlockBody                 = 28
    SketchHashes              = 29
    VerificationPacket        = 30

    #MessageType -> byte.
    def toByte(
        self
    ) -> bytes:
        #This is totally redundant. It shouldn't exist.
        #That said, it isn't redundant, as Mypy errors without it.
        result: bytes = self.value.to_bytes(1, "big")
        return result

#Lengths of messages.
#An empty array means the message was just the header.
#A positive number means read X bytes.
#A negative number means read the last length * X bytes.
#A zero means custom logic should be used.
lengths: Dict[MessageType, List[int]] = {
    MessageType.Handshake:                 [37],
    MessageType.BlockchainTail:            [32],

    MessageType.Syncing:                   [],
    MessageType.SyncingAcknowledged:       [],
    MessageType.PeersRequest:              [],
    MessageType.Peers:                     [1, -6],
    MessageType.BlockListRequest:          [34],
    MessageType.BlockList:                 [1, -32, 32],

    MessageType.BlockHeaderRequest:        [32],
    MessageType.BlockBodyRequest:          [32],
    MessageType.SketchHashesRequest:       [32],
    MessageType.SketchHashRequests:        [32, 4, -8],
    MessageType.TransactionRequest:        [32],
    MessageType.DataMissing:               [],
    MessageType.SyncingOver:               [],

    MessageType.Claim:                     [1, -33, 80],
    MessageType.Send:                      [1, -33, 1, -40, 68],
    MessageType.Data:                      [32, 1, -1, 69],

    MessageType.SignedVerification:        [82],
    MessageType.SignedSendDifficulty:      [86],
    MessageType.SignedDataDifficulty:      [86],
    MessageType.SignedMeritRemoval:        [4, 0, 1, 0, 48],

    MessageType.BlockHeader:               [107, 0, 56],
    MessageType.BlockBody:                 [4, -8, 4, 0, 48],
    MessageType.SketchHashes:              [4, -8],
    MessageType.VerificationPacket:        [2, -2, 32]
}

class Meros:
    #Constructor.
    def __init__(
        self,
        test: str,
        tcp: int,
        rpc: int
    ) -> None:
        #Save the config.
        self.db: str = test
        self.tcp: int = tcp
        self.rpc: int = rpc

        #Create the instance.
        self.process: Popen[Any] = Popen(["./build/Meros", "--no-gui", "--data-dir", "./data/PythonTests", "--db", test, "--network", "devnet", "--tcp-port", str(tcp), "--rpc-port", str(rpc)])

        #Create message/response lists.
        self.msgs: List[bytes] = []
        self.ress: List[bytes] = []

    #Send a message.
    def send(
        self,
        msg: bytes,
        save: bool = True
    ) -> None:
        try:
            self.connection.send(msg)
            if save:
                self.msgs.append(msg)
        except:
            raise TestError("Node disconnected us as a peer.")

    #Receive X bytes from the socket.
    def socketRecv(
        self,
        length: int
    ) -> bytes:
        try:
            result: bytes = self.connection.recv(length)
            if len(result) != length:
                raise Exception("")
            return result
        except:
            raise TestError("Node disconnected us as a peer.")

    #Receive a message.
    def recv(
        self
    ) -> bytes:
        #Receive the header.
        result: bytes = self.socketRecv(1)
        header: MessageType = MessageType(result[0])

        #If this was SyncingOver, add an empty bytes.
        #This is so playback works.
        if header == MessageType.SyncingOver:
            self.msgs.append(bytes())

        #Get the rest of the message.
        length: int
        for l in range(len(lengths[header])):
            length = lengths[header][l]
            if length < 0:
                length = int.from_bytes(
                    result[-lengths[header][l - 1]:],
                    byteorder="big"
                ) * abs(length)
            elif length == 0:
                if header == MessageType.SignedMeritRemoval:
                    if result[-1] == 0:
                        length = 32
                    elif result[-1] == 1:
                        result += self.socketRecv(2)
                        length = (int.from_bytes(result[-2:], byteorder="big") * 96) + 32
                    elif result[-1] == 2:
                        length = 36
                    elif result[-1] == 3:
                        length = 36
                    else:
                        raise Exception("Meros sent an Element we don't recognize.")

                elif header == MessageType.BlockHeader:
                    if result[-1] == 1:
                        length = 96
                    else:
                        length = 2

                elif header == MessageType.BlockBody:
                    elementsLen: int = int.from_bytes(result[-4:], byteorder="big")
                    for _ in range(elementsLen):
                        result += self.socketRecv(1)
                        if result[-1] == 2:
                            result += self.socketRecv(38)
                        elif result[-1] == 3:
                            result += self.socketRecv(38)
                        elif result[-1] == 4:
                            result += self.socketRecv(10)
                        elif result[-1] == 5:
                            result += self.socketRecv(4)
                            for e in range(2):
                                if result[-1] == 0:
                                    result += self.socketRecv(32)
                                elif result[-1] == 1:
                                    result += self.socketRecv(2)
                                    result += self.socketRecv((int.from_bytes(result[-2:], byteorder="big") * 96) + 32)
                                elif result[-1] == 2:
                                    result += self.socketRecv(36)
                                elif result[-1] == 3:
                                    result += self.socketRecv(36)
                                elif result[-1] == 4:
                                    result += self.socketRecv(8)
                                if e == 0:
                                    result += self.socketRecv(1)
                        else:
                            raise Exception("Block Body has an unknown element.")

            result += self.socketRecv(length)

        if header not in {
            MessageType.Handshake,
            MessageType.PeersRequest,
            MessageType.Peers
        }:
            self.ress.append(result)
        return result

    #Connect to Meros and handshake with it.
    def connect(
        self,
        network: int,
        protocol: int,
        tail: bytes
    ) -> None:
        #Save the network/protocol.
        self.network = network
        self.protocol = protocol

        #Connect.
        self.connection: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.connection.connect(("127.0.0.1", self.tcp))

        #Send our handshake.
        self.send(
            MessageType.Handshake.toByte() +
            network.to_bytes(1, "big") +
            protocol.to_bytes(1, "big") +
            b'\0\0\0' +
            tail,
            False
        )

        #Receive their handshake.
        response: bytes = self.recv()

        #Verify their network/protocol.
        if MessageType(response[0]) != MessageType.Handshake:
            raise Exception("Node didn't send a Handshake.")
        if response[1] != network:
            raise Exception("Connected to a node on a diffirent network.")
        if response[2] != protocol:
            raise Exception("Connected to a node using a diffirent protocol.")

    #Start Syncing.
    def syncing(
        self
    ) -> bytes:
        res: bytes = MessageType.Syncing.toByte()
        self.send(res)
        return res

    #Send Syncing Acknowledged.
    def syncingAcknowledged(
        self
    ) -> bytes:
        res: bytes = MessageType.SyncingAcknowledged.toByte()
        self.send(res)
        return res

    #Send a peers request.
    def peersRequest(
        self
    ) -> bytes:
        res: bytes = MessageType.PeersRequest.toByte()
        self.send(res, False)
        return res

    #Send peers.
    def peers(
        self,
        peers: List[Tuple[str, int]]
    ) -> bytes:
        res: bytes = MessageType.Peers.toByte()
        for peer in peers:
            ipParts: List[str] = peer[0].split(".")
            res += (
                int(ipParts[0]).to_bytes(1, byteorder="big") +
                int(ipParts[1]).to_bytes(1, byteorder="big") +
                int(ipParts[2]).to_bytes(1, byteorder="big") +
                int(ipParts[3]).to_bytes(1, byteorder="big") +
                peer[1].to_bytes(2, byteorder="big")
            )
        self.send(res, False)
        return res

    #Send a Block List.
    def blockList(
        self,
        hashes: List[bytes]
    ) -> bytes:
        res: bytes = (
            MessageType.BlockList.toByte() +
            (len(hashes) - 1).to_bytes(1, byteorder="big")
        )
        for blockHash in hashes:
            res += blockHash
        self.send(res)
        return res

    #Send a Data Missing.
    def dataMissing(
        self
    ) -> bytes:
        res: bytes = MessageType.DataMissing.toByte()
        self.send(res)
        return res

    #Send a Transaction.
    def transaction(
        self,
        tx: Transaction
    ) -> bytes:
        res: bytes = bytes()
        if isinstance(tx, Claim):
            res = MessageType.Claim.toByte()
        elif isinstance(tx, Send):
            res = MessageType.Send.toByte()
        elif isinstance(tx, Data):
            res = MessageType.Data.toByte()
        res += tx.serialize()

        self.send(res)
        return res

    #Send a Signed Element.
    def signedElement(
        self,
        elem: SignedElement,
        lookup: List[bytes] = []
    ) -> bytes:
        res: bytes = bytes()
        if isinstance(elem, SignedVerification):
            res = MessageType.SignedVerification.toByte()
        elif isinstance(elem, SignedDataDifficulty):
            res = MessageType.SignedDataDifficulty.toByte()
        elif isinstance(elem, SignedSendDifficulty):
            res = MessageType.SignedSendDifficulty.toByte()
        elif isinstance(elem, PartialMeritRemoval):
            res = MessageType.SignedMeritRemoval.toByte()
        else:
            raise Exception("Unsupported Element passed to Meros.signedElement.")
        res += elem.signedSerialize(lookup)

        self.send(res)
        return res

    #Send a Block Header.
    def blockHeader(
        self,
        header: BlockHeader
    ) -> bytes:
        res: bytes = (
            MessageType.BlockHeader.toByte() +
            header.serialize()
        )
        self.send(res)
        return res

    #Send a Block Body.
    def blockBody(
        self,
        lookup: List[bytes],
        block: Block
    ) -> bytes:
        res: bytes = (
            MessageType.BlockBody.toByte() +
            block.body.serialize(lookup, block.header.sketchSalt)
        )
        self.send(res)
        return res

    #Send sketch hashes.
    def sketchHashes(
        self,
        hashes: List[int]
    ) -> bytes:
        res: bytes = MessageType.SketchHashes.toByte() + len(hashes).to_bytes(4, byteorder="big")
        for sketchHash in hashes:
            res += sketchHash.to_bytes(8, byteorder="big")
        self.send(res)
        return res

    #Send a Verification Packet.
    def packet(
        self,
        packet: VerificationPacket
    ) -> bytes:
        res: bytes = (
            MessageType.VerificationPacket.toByte() +
            packet.serialize()
        )
        self.send(res)
        return res

    #Playback all received messages and test the responses.
    def playback(
        self
    ) -> None:
        for i in range(len(self.ress)):
            self.send(self.ress[i])
            if len(self.msgs[i]) != 0:
                buf: bytes = self.recv()
                if self.msgs[i] != buf:
                    raise TestError("Invalid playback response.")

    #Check the return code.
    def quit(
        self
    ) -> None:
        while self.process.poll() == None:
            pass

        if self.process.returncode != 0:
            raise NodeError("Meros didn't quit with code 0.")
