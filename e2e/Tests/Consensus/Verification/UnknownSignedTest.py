from time import time, sleep
import json

import e2e.Libs.Ristretto.ed25519 as ed25519

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
  chain: Blockchain
  with open("e2e/Vectors/Merit/BlankBlocks.json", "r") as file:
    chain = Blockchain.fromJSON(json.loads(file.read()))

  #Send a single block so we have a miner.
  rpc.meros.liveConnect(chain.blocks[0].header.hash)
  rpc.meros.syncConnect(chain.blocks[0].header.hash)
  header: bytes = rpc.meros.liveBlockHeader(chain.blocks[1].header)
  rpc.meros.handleBlockBody(chain.blocks[1])
  if rpc.meros.live.recv() != header:
    raise TestError("Meros didn't broadcast the header.")

  #Create a valid Data.
  #Uneccessary at this time, but good preparation for the future.
  privKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
  data: Data = Data(bytes(32), privKey.get_verifying_key())
  data.sign(privKey)
  data.beat(SpamFilter(5))

  #Sign the Data.
  verif: SignedVerification = SignedVerification(data.hash)
  verif.sign(0, PrivateKey(0))

  #Run twice. The first shouldn't send the Transaction. The second should.
  for i in range(2):
    rpc.meros.signedElement(verif)
    if MessageType(rpc.meros.sync.recv()[0]) != MessageType.TransactionRequest:
      raise TestError("Meros didn't request the transaction.")

    if i == 0:
      #When we send DataMissing, we should be disconnected within a few seconds.
      rpc.meros.dataMissing()
      start: int = int(time())
      try:
        rpc.meros.sync.recv()
      except Exception:
        #More than a few seconds is allowed as Meros's own SyncRequest must timeout.
        if int(time()) - start > 10:
          raise TestError("Meros didn't disconnect us for sending a Verification of a non-existent Transaction.")
      #Clear our invalid connections.
      rpc.meros.live.connection.close()
      rpc.meros.sync.connection.close()
      sleep(65)
      #Init new ones.
      rpc.meros.liveConnect(chain.blocks[0].header.hash)
      rpc.meros.syncConnect(chain.blocks[0].header.hash)

    else:
      rpc.meros.syncTransaction(data)
      sleep(2)
      if not rpc.call("consensus", "getStatus", {"hash": data.hash.hex()})["verifiers"]:
        raise TestError("Meros didn't add the Verification.")
