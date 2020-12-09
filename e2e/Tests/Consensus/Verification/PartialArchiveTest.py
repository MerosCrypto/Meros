from typing import Dict, List, Any
import json

from pytest import raises

from e2e.Libs.BLS import PrivateKey
from e2e.Libs.RandomX import RandomX

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Merit.BlockHeader import BlockHeader

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError, SuccessError

def PartialArchiveTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/Verification/PartialArchive.json", "r") as file:
    vectors = json.loads(file.read())

  data: Data = Data.fromJSON(vectors["data"])
  svs: List[SignedVerification] = [
    SignedVerification.fromSignedJSON(vectors["verifs"][0]),
    SignedVerification.fromSignedJSON(vectors["verifs"][1])
  ]

  key: PrivateKey = PrivateKey(bytes.fromhex(rpc.call("personal", "getMiner")))

  def sendDataAndVerifications() -> None:
    if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
      raise TestError("Meros didn't rebroadcast a Transaction we sent it.")
    for sv in svs:
      if rpc.meros.signedElement(sv) != rpc.meros.live.recv():
        raise TestError("Meros didn't rebroadcast a SignedVerification we sent it.")

    #As we don't have a quality RPC route for this, we need to use getTemplate.
    if bytes.fromhex(
      rpc.call("merit", "getBlockTemplate", [key.toPublicKey().serialize().hex()])["header"]
    )[36 : 68] != BlockHeader.createContents([VerificationPacket(data.hash, [0, 1])]):
      raise TestError("New Block template doesn't have a properly created packet.")

  def verifyRecreation() -> None:
    template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", [key.toPublicKey().serialize().hex()])
    if bytes.fromhex(template["header"])[36 : 68] != BlockHeader.createContents([VerificationPacket(data.hash, [1])]):
      raise TestError("New Block template doesn't have a properly recreated packet.")

    #Mining it further verifies the internal state.
    difficulty: int = int(rpc.call("merit", "getDifficulty"), 16)
    header: bytes = bytes.fromhex(template["header"])
    proof: int = 0
    sig: bytes
    while True:
      initial: bytes = RandomX(header + proof.to_bytes(4, byteorder="little"))
      sig = key.sign(initial).serialize()
      final: bytes = RandomX(initial + sig)
      if (
        int.from_bytes(final, "little") *
        difficulty
      ) < int.from_bytes(bytes.fromhex("FF" * 32), "little"):
        break
      proof += 1

    rpc.call(
      "merit",
      "publishBlock",
      [
        template["id"],
        (header + proof.to_bytes(4, byteorder="little") + sig).hex()
      ]
    )

    raise SuccessError("Stop Liver from trying to verify the vector chain which doesn't have this Block.")

  #We may not want to use Liver here.
  #There's a very small Block count and we can't let it terminate (hence the SE).
  with raises(SuccessError):
    Liver(
      rpc,
      vectors["blockchain"],
      callbacks={
        2: sendDataAndVerifications,
        3: verifyRecreation
      }
    ).live()
