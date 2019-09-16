#Types.
from typing import Dict, List

#Transactions classes.
from PythonTests.Classes.Transactions.Transaction import Transaction
from PythonTests.Classes.Transactions.Claim import Claim
from PythonTests.Classes.Transactions.Send import Send
from PythonTests.Classes.Transactions.Data import Data

#Consensus classes.
from PythonTests.Classes.Consensus.Element import Element, SignedElement
from PythonTests.Classes.Consensus.Verification import Verification, SignedVerification
from PythonTests.Classes.Consensus.MeritRemoval import MeritRemoval, PartiallySignedMeritRemoval

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
    BlockHeight = 1

    Syncing = 2
    SyncingAcknowledged = 3
    BlockHeaderRequest = 7
    BlockBodyRequest = 8
    ElementRequest = 9
    TransactionRequest = 10
    GetBlockHash = 11
    BlockHash = 12
    DataMissing = 16
    SyncingOver = 17

    Claim = 18
    Send = 19
    Data = 20

    SignedVerification = 23
    SignedMeritRemoval = 27

    BlockHeader = 29
    BlockBody = 30
    Verification = 31
    MeritRemoval = 35

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
#A negative number means read the last byte * X bytes,
#A zero means custom logic should be used.
lengths: Dict[MessageType, List[int]] = {
    MessageType.Handshake: [7],
    MessageType.BlockHeight: [4],

    MessageType.Syncing: [],
    MessageType.SyncingAcknowledged: [],
    MessageType.BlockHeaderRequest: [48],
    MessageType.BlockBodyRequest: [48],
    MessageType.ElementRequest: [52],
    MessageType.TransactionRequest: [48],
    MessageType.GetBlockHash: [4],
    MessageType.BlockHash: [48],
    MessageType.DataMissing: [],
    MessageType.SyncingOver: [],

    MessageType.Claim: [1, -48, 128],
    MessageType.Send: [1, -49, 1, -40, 68],
    MessageType.Data: [49, -1, 68],

    MessageType.SignedVerification: [196],
    MessageType.SignedMeritRemoval: [50, 0],

    MessageType.BlockHeader: [204],
    MessageType.BlockBody: [4, 0],
    MessageType.Verification: [100],
    MessageType.MeritRemoval: [50, 0]
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
        for length in lengths[header]:
            if length > 0:
                result += self.socketRecv(length)
            elif length < 0:
                result += self.socketRecv(result[-1] * abs(length))
            else:
                if header == MessageType.SignedMeritRemoval:
                    if result[-1] == 0:
                        result += self.socketRecv(52)
                    else:
                        raise Exception("Meros sent an Element we don't recognize.")

                    result += self.socketRecv(1)

                    if result[-1] == 0:
                        result += self.socketRecv(52)
                    else:
                        raise Exception("Meros sent an Element we don't recognize.")

                    result += self.socketRecv(96)
                elif header == MessageType.BlockBody:
                    result += self.socketRecv((int.from_bytes(result[1 : 5], "big") * 100) + 1)
                    result += self.socketRecv(result[-1] * 49)
                elif header == MessageType.MeritRemoval:
                    if result[-1] == 0:
                        result += self.socketRecv(53)
                    else:
                        raise Exception("Meros sent an Element we don't recognize.")

                    if result[-1] == 0:
                        result += self.socketRecv(52)
                    else:
                        raise Exception("Meros sent an Element we don't recognize.")
                else:
                    raise Exception("recv was told to use custom logic where no custom logic was implement.")

        if header != MessageType.Handshake:
            self.ress.append(result)
        return result

    #Connect to Meros and handshake with it.
    def connect(
        self,
        network: int,
        protocol: int,
        height: int
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
            height.to_bytes(4, "big"),
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

    #Handshake.
    def handshake(
        self,
        height: int
    ) -> bytes:
        res: bytes = (
            MessageType.Handshake.toByte() +
            self.network.to_bytes(1, "big") +
            self.protocol.to_bytes(1, "big") +
            b'\0' +
            height.to_bytes(4, "big")
        )
        self.send(res)
        return res

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

    #Send a Block Hash.
    def blockHash(
        self,
        hash: bytes
    ) -> bytes:
        res: bytes = (
            MessageType.BlockHash.toByte() +
            hash
        )
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
        elif isinstance(elem, PartiallySignedMeritRemoval):
            res = MessageType.SignedMeritRemoval.toByte()
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

    #Send an Element.
    def element(
        self,
        elem: Element
    ) -> bytes:
        res: bytes = bytes()
        if isinstance(elem, Verification):
            res = MessageType.Verification.toByte()
        elif isinstance(elem, MeritRemoval):
            res = MessageType.MeritRemoval.toByte()
        else:
            raise Exception("Unsigned Element passed to Meros.element.")
        res += elem.serialize()

        self.send(res)
        return res

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
