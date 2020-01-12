#Blockchain class.

#Transactions classes.
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter
from PythonTests.Classes.Transactions.Data import Data

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#RPC class.
from PythonTests.Meros.RPC import RPC

#Transactions verifier.
from PythonTests.Tests.Transactions.Verify import verifyTransaction

#Ed25519 lib.
import ed25519

#Sleep standard function.
from time import sleep

#Ed25519 keys.
privKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
pubKey: ed25519.VerifyingKey = privKey.get_verifying_key()

def DataTest(
    rpc: RPC
) -> None:
    #Get the genesis hash.
    genesis: bytes = Blockchain(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16)
    ).blocks[0].header.hash

    #Create the Spam Filter.
    spamFilter: SpamFilter = SpamFilter(
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )

    #Create the Data.
    data: Data = Data(
        bytes(32),
        pubKey.to_bytes()
    )
    data.sign(privKey)
    data.beat(spamFilter)

    #Handshake with the node.
    rpc.meros.connect(254, 254, genesis)

    #Send the Data.
    rpc.meros.transaction(data)

    #Sleep for 100 milliseconds.
    sleep(0.1)

    #Verify the Data.
    verifyTransaction(rpc, data)
