#https://github.com/MerosCrypto/Meros/issues/106. Specifically tests signed elements (except MeritRemovals).

from typing import List
from time import sleep

import e2e.Libs.Ristretto.Ristretto as Ristretto
from e2e.Libs.BLS import PrivateKey, Signature

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Consensus.Element import SignedElement
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.SendDifficulty import SignedSendDifficulty
from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def HundredSixSignedElementsTest(
  rpc: RPC
) -> None:
  #Solely used to get the genesis Block hash.
  blockchain: Blockchain = Blockchain()

  edPrivKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
  blsPrivKey: PrivateKey = PrivateKey(0)
  sig: Signature = blsPrivKey.sign(bytes())

  #Create a Data for the Verification.
  data: Data = Data(bytes(32), edPrivKey.get_verifying_key())
  data.sign(edPrivKey)
  data.beat(SpamFilter(5))

  #Create a signed Verification, SendDifficulty, and DataDifficulty.
  elements: List[SignedElement] = [
    SignedVerification(data.hash, 1, sig),
    SignedSendDifficulty(0, 0, 1, sig),
    SignedDataDifficulty(0, 0, 1, sig)
  ]

  dataSent: bool = False
  for elem in elements:
    #Handshake with the node.
    rpc.meros.liveConnect(blockchain.blocks[0].header.hash)

    #Send the Data if we have yet to.
    if not dataSent:
      if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
        raise TestError("Data wasn't rebroadcasted.")
      dataSent = True

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
