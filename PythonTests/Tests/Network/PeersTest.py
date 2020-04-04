#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#TestError and SuccessError Exceptions.
from PythonTests.Tests.Errors import TestError, SuccessError

#Sleep standard function.
from time import sleep

#Socket and select standard libs.
import socket
import select

#pylint: disable=too-many-statements
def PeersTest(
    rpc: RPC
) -> None:
    #Blockchain. Solely used to get the genesis Block hash.
    blockchain: Blockchain = Blockchain()

    #Handshake with the node.
    rpc.meros.syncConnect(blockchain.blocks[0].header.hash)

    #Verify that sending a PeersRequest returns 0 peers.
    rpc.meros.peersRequest()
    if len(rpc.meros.sync.recv()) != 2:
        raise TestError("Meros sent peers.")

    #Create a new connection as a server socket.
    serverConnection: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    serverConnection.connect(("127.0.0.1", rpc.meros.tcp))
    serverConnection.send(
        MessageType.Syncing.toByte() +
        (254).to_bytes(1, "big") +
        (254).to_bytes(1, "big") +
        (128).to_bytes(1, "big") + (6000).to_bytes(2, "big") +
        blockchain.blocks[0].header.hash,
        False
    )
    serverConnection.recv(38)
    sleep(1)

    #Verify Meros tracks us as a peer to connect to.
    rpc.meros.peersRequest()
    res: bytes = rpc.meros.sync.recv()
    if len(res) != 8:
        raise TestError("Meros didn't send us the one peer.")
    if res[1] != 1:
        raise TestError("Meros didn't claim to send us one peer.")
    if res[2:] != (bytes.fromhex("7F000001") + (6000).to_bytes(2, "big")):
        raise TestError("Meros didn't send us an accurate peer.")

    #Verify if we ask for peers, Meros doesn't tell us ourselves.
    serverConnection.send(MessageType.PeersRequest.toByte())
    res = serverConnection.recv(2)
    if res[1] != 0:
        raise TestError("Meros either sent us ourselves for a peer or sent a peer who isn't a server.")

    #Close the server and verify Meros loses us as a peer.
    serverConnection.close()
    res = rpc.meros.sync.recv()
    if MessageType(res[0]) != MessageType.Syncing:
        raise Exception("Expected Syncing.")
    rpc.meros.sync.send(MessageType.BlockchainTail.toByte() + blockchain.blocks[0].header.hash)
    sleep(10)

    rpc.meros.peersRequest()
    res = rpc.meros.sync.recv()
    if res[1] != 0:
        raise TestError("Meros suggested a disconnected peer.")

    #Receive Syncing until Meros asks for peers.
    while True:
        res = rpc.meros.sync.recv()
        if MessageType(res[0]) == MessageType.Syncing:
            rpc.meros.sync.send(MessageType.BlockchainTail.toByte() + blockchain.blocks[0].header.hash)
        elif MessageType(res[0]) == MessageType.PeersRequest:
            break

    #Launch a server for Meros to connect to.
    server: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(("127.0.0.1", 0))
    server.listen(2)

    #Craft a Peers message of our own server.
    rpc.meros.sync.send(
        MessageType.Peers.toByte() +
        bytes.fromhex("017F000001") +
        server.getsockname()[1].to_bytes(2, "big")
    )

    #Use select to obtain a non-blocking accept.
    for _ in select.select([server], [], [], 5000):
        #Accept a new connection.
        client, _ = server.accept()

        #Verify Meros's Handshake.
        buf: bytes = client.recv(38)
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
        raise SuccessError("Meros connected to us as a new peer.")

    #Raise a TestError.
    server.close()
    raise TestError("Meros didn't connect to our server.")
