from typing import IO, Any
import json

import ed25519

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC
from e2e.Meros.Meros import MessageType

from e2e.Tests.Errors import TestError

def VUnknownSignedTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
  chain: Blockchain = Blockchain.fromJSON(json.loads(file.read()))
  file.close()

  #Send a single block so we have a miner.
  rpc.meros.liveConnect(chain.blocks[0].header.hash)
  rpc.meros.syncConnect(chain.blocks[0].header.hash)
  header: bytes = rpc.meros.liveBlockHeader(chain.blocks[1].header)
  if MessageType(rpc.meros.sync.recv()[0]) != MessageType.BlockBodyRequest:
    raise TestError("Meros didn't ask for the body.")
  rpc.meros.blockBody(chain.blocks[1])
  if rpc.meros.live.recv() != header:
    raise TestError("Meros didn't broadcast the header.")

  #Create a valid Data.
  #Uneccessary at this time, but good preparation for the future.
  privKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
  data: Data = Data(bytes(32), privKey.get_verifying_key().to_bytes())
  data.sign(privKey)
  data.beat(SpamFilter(5))

  verif: SignedVerification = SignedVerification(data.hash)
  verif.sign(0, PrivateKey(0))
  rpc.meros.signedElement(verif)
