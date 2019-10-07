#Types.
from typing import Dict, List

#Transactions classes.
from PythonTests.Classes.Transactions.Transaction import Transaction
from PythonTests.Classes.Transactions.Claim import Claim
from PythonTests.Classes.Transactions.Send import Send
from PythonTests.Classes.Transactions.Data import Data

#Consensus classes.
from PythonTests.Classes.Consensus.Element import Element, SignedElement
from PythonTests.Classes.Consensus.Verification import SignedVerification
#from PythonTests.Classes.Consensus.MeritRemoval import MeritRemoval, PartiallySignedMeritRemoval

#Merit classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Enum class.
from enum import Enum

#Subprocess class.
from subprocess import Popen

#Socket standard lib.
import socket

#Message Types.
class MessageType(Enum):
    Handshake = 0
    BlockchainTail = 1

    Syncing = 2
    SyncingAcknowledged = 3
    BlockListRequest = 6,
    BlockList = 7,

    BlockHeaderRequest = 9
    BlockBodyRequest = 10
    VerificationPacketRequest = 11
    TransactionRequest = 12
    DataMissing = 14
    SyncingOver = 15

    Claim = 16
    Send = 17
    Data = 18

    SignedVerification = 21
    SignedVerificationPacket = 22,
    SignedMeritRemoval = 26

    BlockHeader = 28
    BlockBody = 29
    VerificationPacket = 30

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
#A negative number means read the last section * X bytes,
#A zero means custom logic should be used.
lengths: Dict[MessageType, List[int]] = {
    MessageType.Handshake: [51],
    MessageType.BlockchainTail: [48],

    MessageType.Syncing: [],
    MessageType.SyncingAcknowledged: [],
    MessageType.BlockListRequest: [50],
    MessageType.BlockList: [1, -48],

    MessageType.BlockHeaderRequest: [48],
    MessageType.BlockBodyRequest: [48],
    MessageType.VerificationPacketRequest: [96],
    MessageType.TransactionRequest: [48],
    MessageType.DataMissing: [],
    MessageType.SyncingOver: [],

    MessageType.Claim: [1, -48, 128],
    MessageType.Send: [1, -49, 1, -40, 68],
    MessageType.Data: [48, 1, -1, 68],

    MessageType.SignedVerification: [146],
    MessageType.SignedVerificationPacket: [1, -2, 48 + 96],
    MessageType.SignedMeritRemoval: [4, 0, 1, 0, 96],

    MessageType.BlockHeader: [149, 104],
    MessageType.BlockBody: [4, -48, 4, 0, 96],
    MessageType.VerificationPacket: [1, -2, 48]
}

class Meros:
    #Constructor.
    def __init__(
        self,
        db: str,
        tcp: int,
        rpc: int
    ) -> None:
        #Save the config.
        self.db: str = db
        self.tcp: int = tcp
        self.rpc: int = rpc

        #Create the instance.
        self.process: Popen = Popen(["./build/Meros", "--gui", "false", "--dataDir", "./data/PythonTests", "--network", "devnet", "--db", db, "--tcpPort", str(tcp), "--rpcPort", str(rpc)])

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

        #If this was SyncingOver, add an empty bytesself.
        #This is so playback works.
        if header == MessageType.SyncingOver:
            self.msgs.append(bytes())

        #Get the rest of the message.
        for l in range(len(lengths[header])):
            length: int = lengths[header][l]
            if length < 0:
                length = int.from_bytes(
                    result[-lengths[header][l - 1]:],
                    byteorder="big"
                ) * abs(length)
            else:
                if header == MessageType.SignedMeritRemoval:
                    if result[-1] == 0:
                        length = 50
                    else:
                        raise Exception("Meros sent an Element we don't recognize.")

                elif header == MessageType.BlockHeader:
                    if result[-1] == 1:
                        length = 96
                    else:
                        length = 2

                elif header == MessageType.BlockBody:
                    """
                    """

            result += self.socketRecv(length)

        if header != MessageType.Handshake:
            self.ress.append(result)
        return result

    #Connect to Meros and handshake with it.
    def connect(
        self,
        network: int,
        protocol: int,
        tail: bytes
    ) -> int:
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
            b'\0' +
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

        #Return their height.
        return int.from_bytes(response[3 : 7], "big")

    #Start syncing.
    def syncing(
        self
    ) -> bytes:
        res: bytes = MessageType.Syncing.toByte()
        self.send(res)
        return res

    #Acknowledge syncing.
    def acknowledgeSyncing(
        self
    ) -> bytes:
        res: bytes = MessageType.SyncingAcknowledged.toByte()
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
        elem: Element
    ) -> bytes:
        res: bytes = bytes()
        if isinstance(elem, SignedVerification):
            res = MessageType.SignedVerification.toByte()
        else:
            raise Exception("Unsupported Element passed to Meros.signedElement.")
        res += SignedElement.fromElement(elem).signedSerialize()

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
        body: BlockBody
    ) -> bytes:
        res: bytes = (
            MessageType.BlockBody.toByte() +
            body.serialize()
        )
        self.send(res)
        return res

    #Send a VerificationPacket.
    """
    def packet(
        self,
        packet: VerificationPacket
    ) -> bytes:
        res: bytes = bytes()
        self.send(res)
        return res
    """

    #Playback all received messages and test the responses.
    def playback(
        self
    ) -> None:
        for i in range(len(self.ress)):
            self.send(self.ress[i])
            if len(self.msgs[i]) != 0:
                if self.msgs[i] != self.recv():
                    raise TestError("Invalid playback response.")

    #Check the return code.
    def quit(
        self
    ) -> None:
        while self.process.poll() == None:
            pass
        if self.process.returncode != 0:
            raise Exception("Meros didn't quit with code 0.")
