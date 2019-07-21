# pyright: strict

#Merit classes.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody

#Transactions classes.
from python_tests.Classes.Transactions.Data import Data

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
        result: bytes = self.value.to_bytes(1, byteorder="big")
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
        self.process: Popen = Popen(["./build/Meros", "--dataDir", "./data/python_tests", "--network", "devnet", "--db", db, "--tcpPort", str(tcp), "--rpcPort", str(rpc)])

    #Send a message.
    def send(
        self,
        msg: bytes
    ) -> None:
        self.connection.send(msg)

    #Receive a message.
    def recv(
        self
    ) -> bytes:
        #Receive the header.
        result: bytes = self.connection.recv(1)

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

        #elif MessageType(result[0]) == MessageType.Claim:
        #    size = CLAIM_LENS[0]
        #elif MessageType(result[0]) == MessageType.Send:
        #    size = SEND_LENS[0]
        #elif MessageType(result[0]) == MessageType.Data:
        #    size = DATA_PREFIX_LEN

        #elif MessageType(result[0]) == MessageType.SignedVerification:
        #    size = SIGNED_VERIFICATION_LEN
        #elif MessageType(result[0]) == MessageType.SignedMeritRemoval:
        #    size = MERIT_REMOVAL_LENS[0]

        elif MessageType(result[0]) == MessageType.BlockHeader:
            size = 204
        elif MessageType(result[0]) == MessageType.BlockBody:
            size = 4
        #elif MessageType(result[0]) == MessageType.Verification:
        #    size = VERIFICATION_LEN
        #elif MessageType(result[0]) == MessageType.MeritRemoval:
        #    size = MERIT_REMOVAL_LENS[0]

        #Now that we know how long the message is, get it (as long as there is one).
        if size > 0:
            result += self.connection.recv(size)

        #If this is a MessageType with more data...
        #if MessageType(result[0]) == MessageType.Claim:
        #    result += self.connection.recv((int.from_bytes(result[1]) * CLAIM_LENS[1]) + CLAIM_LENS[2])

        #elif MessageType(result[0]) == MessageType.Send:
        #    result += self.connection.recv((int.from_bytes(result[1]) * SEND_LENS[1]) + SEND_LENS[2]
        #    result += self.connection.recv((int.from_bytes(result[len(result) - 1 : len(result)], byteorder="big") * SEND_LENS[3]) + SEND_LENS[4]

        #elif MessageType(result[0]) == MessageType.Data:
        #    result += self.connection.recv((int.from_bytes(result[len(result) - 1 : len(result)], byteorder="big") + DATA_SUFFIX_LEN

        #elif MessageType(result[0]) == MessageType.SignedMeritRemoval:
        #    result += self.connection.recv((int.from_bytes(result[len(result) - 1 : len(result)], byteorder="big") + MERIT_REMOVAL_LENS[2]
        #    result += self.connection.recv((int.from_bytes(result[len(result) - 1 : len(result)], byteorder="big") + MERIT_REMOVAL_LENS[4]

        if MessageType(result[0]) == MessageType.BlockBody:
            result += self.connection.recv((int.from_bytes(result[1 : 5], byteorder="big") * 100) + 1)
            result += self.connection.recv(int.from_bytes(result[len(result) - 1 : len(result)], byteorder="big") + 49)

        #elif MessageType(result[0]) == MessageType.MeritRemoval:
        #    result += self.connection.recv((int.from_bytes(result[len(result) - 1 : len(result)], byteorder="big") + MERIT_REMOVAL_LENS[2]
        #    result += self.connection.recv((int.from_bytes(result[len(result) - 1 : len(result)], byteorder="big")

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
            network.to_bytes(1, byteorder="big") +
            protocol.to_bytes(1, byteorder="big") +
            b'\0' +
            height.to_bytes(4, byteorder="big")
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
        return int.from_bytes(response[3 : 7], byteorder="big")

    #Handshake.
    def handshake(
        self,
        height: int
    ) -> bytes:
        res: bytes = (
            MessageType.Handshake.toByte() +
            self.network.to_bytes(1, byteorder="big") +
            self.protocol.to_bytes(1, byteorder="big") +
            b'\0' +
            height.to_bytes(4, byteorder="big")
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

    #Send a Data.
    def data(
        self,
        data: Data
    ) -> bytes:
        res: bytes = (
            MessageType.Data.toByte() +
            data.serialize()
        )
        self.send(res)
        return res

    #Check the return code.
    def quit(
        self
    ) -> None:
        while self.process.poll() == None:
            pass
        if self.process.returncode != 0:
            raise Exception("Meros didn't quit with code 0.")
