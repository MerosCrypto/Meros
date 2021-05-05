import e2e.Libs.Ristretto.ed25519 as ed25519

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC

from e2e.Tests.Transactions.Verify import verifyTransaction

def DataTest(
  rpc: RPC
) -> None:
  privKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
  pubKey: bytes = privKey.get_verifying_key()

  genesis: bytes = Blockchain().blocks[0].header.hash
  spamFilter: SpamFilter = SpamFilter(5)

  data: Data = Data(bytes(32), pubKey)
  data.sign(privKey)
  data.beat(spamFilter)

  rpc.meros.liveConnect(genesis)
  rpc.meros.liveTransaction(data)
  verifyTransaction(rpc, data)
