#Types.
from typing import List

#Transactions classes.
from python_tests.Classes.Transactions.Transaction import Transaction
from python_tests.Classes.Transactions.Claim import Claim
from python_tests.Classes.Transactions.Send import Send
from python_tests.Classes.Transactions.Data import Data

#Consensus classes.
from python_tests.Classes.Consensus.Element import Element, SignedElement
from python_tests.Classes.Consensus.Verification import Verification, SignedVerification
from python_tests.Classes.Consensus.MeritRemoval import MeritRemoval, PartiallySignedMeritRemoval

#Merit classes.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody

#TestError Exception.
from python_tests.Tests.Errors import TestError

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
        result: bytes = self.value.to_bytes(1, byteorder = "big")
        return result

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
        self.process: Popen = Popen(["./build/Meros", "--gui", "false", "--dataDir", "./data/python_tests", "--network", "devnet", "--db", db, "--tcpPort", str(tcp), "--rpcPort", str(rpc)])

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
        quantity: int
    ) -> bytes:
        try:
            result: bytes = self.connection.recv(quantity)
            if len(result) == 0:
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

        #Determine the Message Size.
        size: int = 0
        if MessageType(result[0]) == MessageType.Handshake:
            size = 7
        elif MessageType(result[0]) == MessageType.BlockHeight:
            size = 4

        elif MessageType(result[0]) == MessageType.Syncing:
            size = 0
        elif MessageType(result[0]) == MessageType.SyncingAcknowledged:
            size = 0
        elif MessageType(result[0]) == MessageType.BlockHeaderRequest:
            size = 48
        elif MessageType(result[0]) == MessageType.BlockBodyRequest:
            size = 48
        elif MessageType(result[0]) == MessageType.ElementRequest:
            size = 52
        elif MessageType(result[0]) == MessageType.TransactionRequest:
            size = 48
        elif MessageType(result[0]) == MessageType.GetBlockHash:
            size = 4
        elif MessageType(result[0]) == MessageType.BlockHash:
            size = 52
        elif MessageType(result[0]) == MessageType.DataMissing:
            size = 0
        elif MessageType(result[0]) == MessageType.SyncingOver:
            size = 0
            self.msgs.append(bytes())

        elif MessageType(result[0]) == MessageType.Claim:
            size = 1
        elif MessageType(result[0]) == MessageType.Send:
            size = 1
        elif MessageType(result[0]) == MessageType.Data:
            size = 49

        elif MessageType(result[0]) == MessageType.SignedVerification:
            size = 196
        elif MessageType(result[0]) == MessageType.SignedMeritRemoval:
            size = 50

        elif MessageType(result[0]) == MessageType.BlockHeader:
            size = 204
        elif MessageType(result[0]) == MessageType.BlockBody:
            size = 4
        elif MessageType(result[0]) == MessageType.Verification:
            size = 100
        elif MessageType(result[0]) == MessageType.MeritRemoval:
            size = 50

        #Now that we know how long the message is, get it (as long as there is one).
        if size > 0:
            result += self.socketRecv(size)

        #If this is a MessageType with more data...
        if MessageType(result[0]) == MessageType.Claim:
            result += self.socketRecv((result[1] * 48) + 128)

        elif MessageType(result[0]) == MessageType.Send:
            result += self.socketRecv((result[1] * 49) + 1)
            result += self.socketRecv((result[-1] * 40) + 68)

        elif MessageType(result[0]) == MessageType.Data:
            result += self.socketRecv(result[-1] + 68)

        elif MessageType(result[0]) == MessageType.SignedMeritRemoval:
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

        elif MessageType(result[0]) == MessageType.BlockBody:
            result += self.socketRecv((int.from_bytes(result[1 : 5], byteorder = "big") * 100) + 1)
            result += self.socketRecv(result[-1] + 49)

        elif MessageType(result[0]) == MessageType.MeritRemoval:
            if result[-1] == 0:
                result += self.socketRecv(53)
            else:
                raise Exception("Meros sent an Element we don't recognize.")

            if result[-1] == 0:
                result += self.socketRecv(52)
            else:
                raise Exception("Meros sent an Element we don't recognize.")

        if MessageType(result[0]) != MessageType.Handshake:
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
            network.to_bytes(1, byteorder = "big") +
            protocol.to_bytes(1, byteorder = "big") +
            b'\0' +
            height.to_bytes(4, byteorder = "big"),
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
        return int.from_bytes(response[3 : 7], byteorder = "big")

    #Handshake.
    def handshake(
        self,
        height: int
    ) -> bytes:
        res: bytes = (
            MessageType.Handshake.toByte() +
            self.network.to_bytes(1, byteorder = "big") +
            self.protocol.to_bytes(1, byteorder = "big") +
            b'\0' +
            height.to_bytes(4, byteorder = "big")
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
