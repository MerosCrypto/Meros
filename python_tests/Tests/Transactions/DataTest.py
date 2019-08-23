#Transactions classes.
from python_tests.Classes.Consensus.SpamFilter import SpamFilter
from python_tests.Classes.Transactions.Data import Data

#RPC class.
from python_tests.Meros.RPC import RPC

#Transactions verifier.
from python_tests.Tests.Transactions.Verify import verifyTransaction

#Ed25519 lib.
import ed25519

#Ed25519 keys.
privKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
pubKey: ed25519.VerifyingKey = privKey.get_verifying_key()

def DataTest(
    rpc: RPC
) -> None:
    #Create the Spam Filter.
    filter: SpamFilter = SpamFilter(
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )

    #Create the Data.
    data: Data = Data(
        pubKey.to_bytes().rjust(48, b'\0'),
        b"Hello There! General Kenobi."
    )
    data.sign(privKey)
    data.beat(filter)

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        0
    )

    #Send the Data.
    rpc.meros.transaction(data)

    #Verify the Data.
    verifyTransaction(rpc, data)
