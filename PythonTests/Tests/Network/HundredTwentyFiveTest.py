#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#TestError and SuccessError Exceptions.
from PythonTests.Tests.Errors import TestError, SuccessError

#Socket standard lib.
import socket

def HundredTwentyFiveTest(
    rpc: RPC
) -> None:
    #Meros allows connections from its own IP if they identify as 127.0.0.1.
    #We need to connect either through the LAN or through the public IP for this test to be valid.
    #The following code grabs the computer's 192 IP.
    lanIPFinder = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    lanIPFinder.connect(("meroscrypto.io", 443))
    lanIP = lanIPFinder.getsockname()[0]
    lanIPFinder.close()

    if not (lanIP.split(".")[0] in {"10", "172", "192"}):
        raise Exception("Failed to get the LAN IP.")

    #Blockchain. Solely used to get the genesis Block hash.
    blockchain: Blockchain = Blockchain()

    #Connect to Meros.
    connection: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    connection.connect((lanIP, rpc.meros.tcp))
    try:
        connection.send(
            MessageType.Syncing.toByte() +
            (254).to_bytes(1, "big") +
            (254).to_bytes(1, "big") +
            (128).to_bytes(1, "big") + (6000).to_bytes(2, "big") +
            blockchain.blocks[0].header.hash,
            False
        )
        if len(connection.recv(38)) == 0:
            raise Exception("")
    except Exception:
        raise SuccessError("Meros closed a connection from the same IP as itself which wasn't 127.0.0.1.")
    raise TestError("Meros allowed a connection from the same IP as itself which wasn't 127.0.0.1.")
