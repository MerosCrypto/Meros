#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Sleep standard function.
from time import sleep

#Socket standard lib.
import socket

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
    sleep(20)

    rpc.meros.peersRequest()
    res = rpc.meros.sync.recv()
    if res[1] != 0:
        raise TestError("Meros suggested a disconnected peer.")
