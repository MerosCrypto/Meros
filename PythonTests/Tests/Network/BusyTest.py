#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#TestError and SuccessError Exceptions.
from PythonTests.Tests.Errors import TestError, SuccessError

#Socket and select standard libs.
import socket
import select

#pylint: disable=too-many-statements
def BusyTest(
    rpc: RPC
) -> None:
    #Blockchain. Solely used to get the genesis Block hash.
    blockchain: Blockchain = Blockchain()

    #Handshake with the node.
    rpc.meros.syncConnect(blockchain.blocks[0].header.hash)

    #Create two new server sockets.
    def createServerSocket() -> socket.socket:
        result: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        result.bind(("127.0.0.1", 0))
        result.listen(2)
        return result
    busyServer: socket.socket = createServerSocket()
    server: socket.socket = createServerSocket()

    #Receive Syncing until Meros asks for peers.
    while True:
        res = rpc.meros.sync.recv()
        if MessageType(res[0]) == MessageType.Syncing:
            rpc.meros.sync.send(MessageType.BlockchainTail.toByte() + blockchain.blocks[0].header.hash)
        elif MessageType(res[0]) == MessageType.PeersRequest:
            break

    #Craft a Peers message of our own server.
    rpc.meros.sync.send(
        MessageType.Peers.toByte() +
        bytes.fromhex("017F000001") +
        busyServer.getsockname()[1].to_bytes(2, "big")
    )

    #Use select to obtain a non-blocking accept.
    busy: int = 0
    buf: bytes
    for _ in select.select([busyServer], [], [], 5000):
        #Accept a new connection.
        client, _ = busyServer.accept()

        #Verify Meros's Handshake.
        buf = client.recv(38)
        if MessageType(buf[0]) not in {MessageType.Handshake, MessageType.Syncing}:
            busyServer.close()
            raise TestError("Meros didn't start its connection with a Handshake.")

        if buf[1:] != (
            (254).to_bytes(1, "big") +
            (254).to_bytes(1, "big") +
            (128).to_bytes(1, "big") + (rpc.meros.tcp).to_bytes(2, "big") +
            blockchain.blocks[0].header.hash
        ):
            busyServer.close()
            raise TestError("Meros had an invalid Handshake.")

        #Send back Busy.
        client.send(
            MessageType.Busy.toByte() +
            bytes.fromhex("017F000001") +
            server.getsockname()[1].to_bytes(2, "big")
        )

        busy += 1
        if busy == 2:
            busyServer.close()
            break

    #Make sure Meros connects to the server we redirected to.
    for _ in select.select([server], [], [], 5000):
        #Accept a new connection.
        client, _ = server.accept()

        #Verify Meros's Handshake.
        buf = client.recv(38)
        if MessageType(buf[0]) not in {MessageType.Handshake, MessageType.Syncing}:
            server.close()
            raise TestError("Meros didn't start its connection with a Handshake.")

        if buf[1:] != (
            (254).to_bytes(1, "big") +
            (254).to_bytes(1, "big") +
            (128).to_bytes(1, "big") + (rpc.meros.tcp).to_bytes(2, "big") +
            blockchain.blocks[0].header.hash
        ):
            server.close()
            raise TestError("Meros had an invalid Handshake.")

        server.close()
        raise SuccessError("Meros connected to the server we redirected it to with a Busy message.")

    #Raise a TestError.
    busyServer.close()
    server.close()
    raise TestError("Meros didn't connect to the redirected server.")
