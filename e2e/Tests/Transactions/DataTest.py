#Transactions classes.
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Transactions.Data import Data

#Blockchain class.
from e2e.Classes.Merit.Blockchain import Blockchain

#RPC class.
from e2e.Meros.RPC import RPC

#Transactions verifier.
from e2e.Tests.Transactions.Verify import verifyTransaction

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
  genesis: bytes = Blockchain().blocks[0].header.hash

  #Create the Spam Filter.
  spamFilter: SpamFilter = SpamFilter(5)

  #Create the Data.
  data: Data = Data(bytes(32), pubKey.to_bytes())
  data.sign(privKey)
  data.beat(spamFilter)

  #Handshake with the node.
  rpc.meros.liveConnect(genesis)

  #Send the Data.
  rpc.meros.liveTransaction(data)

  #Sleep for 100 milliseconds.
  sleep(0.1)

  #Verify the Data.
  verifyTransaction(rpc, data)
