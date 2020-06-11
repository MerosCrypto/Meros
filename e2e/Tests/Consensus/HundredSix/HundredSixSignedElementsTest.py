#https://github.com/MerosCrypto/Meros/issues/106. Specifically tests signed elements (except MeritRemovals).

from typing import List
from time import sleep
from hashlib import blake2b

from e2e.Libs.BLS import PrivateKey, Signature

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Classes.Consensus.Element import SignedElement
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.SendDifficulty import SignedSendDifficulty
from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty

from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def HundredSixSignedElementsTest(
  rpc: RPC
) -> None:
  #Solely used to get the genesis Block hash.
  blockchain: Blockchain = Blockchain()

  blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
  sig: Signature = blsPrivKey.sign(bytes())

  #Create a Data.
  #This is required so the Verification isn't terminated early for having an unknown hash.
  data: bytes = bytes.fromhex(rpc.call("personal", "data", ["AA"]))

  #Create a signed Verification, SendDifficulty, and DataDifficulty.
  elements: List[SignedElement] = [
    SignedVerification(data, 1, sig),
    SignedSendDifficulty(0, 0, 1, sig),
    SignedDataDifficulty(0, 0, 1, sig)
  ]

  for elem in elements:
    #Handshake with the node.
    rpc.meros.liveConnect(blockchain.blocks[0].header.hash)

    #Send the Element.
    rpc.meros.signedElement(elem)

    #Sleep for thirty seconds to make sure Meros realizes our connection is dead.
    sleep(30)

    #Verify the node didn't crash.
    try:
      if rpc.call("merit", "getHeight") != 1:
        raise Exception()
    except Exception:
      raise TestError("Node crashed after being sent a malformed Element.")
