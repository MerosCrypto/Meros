#Transactions classes.
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter
from PythonTests.Classes.Transactions.Data import Data

#RPC class.
from PythonTests.Meros.RPC import RPC

#Transactions verifier.
from PythonTests.Tests.Transactions.Verify import verifyTransaction

#Ed25519 lib.
import ed25519

#Ed25519 keys.
privKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
pubKey: ed25519.VerifyingKey = privKey.get_verifying_key()

def DataTest(
    rpc: RPC
) -> None:
    #Create the Spam Filter.
    spamFilter: SpamFilter = SpamFilter(
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )

    #Create the Data.
    data: Data = Data(
        pubKey.to_bytes().rjust(48, b'\0'),
        b"Hello There! General Kenobi."
    )
    data.sign(privKey)
    data.beat(spamFilter)

    #Handshake with the node.
    rpc.meros.connect(254, 254, 0)

    #Send the Data.
    rpc.meros.transaction(data)

    #Verify the Data.
    verifyTransaction(rpc, data)
