from typing import Dict, List, Tuple, Any
from hashlib import blake2b

import ed25519

from e2e.Classes.Transactions.Transaction import Transaction
from e2e.Classes.Consensus.SpamFilter import SpamFilter

class Send(
  Transaction
):
  inputs: List[Tuple[bytes, int]]
  outputs: List[Tuple[bytes, int]]

  #Separate from serialize as it's called by the constructor.
  def serializeInputs(
    self
  ) -> bytes:
    result: bytes = bytes()
    for txInput in self.inputs:
      result += txInput[0] + txInput[1].to_bytes(1, "little")
    return result

  def serializeOutputs(
    self
  ) -> bytes:
    result: bytes = bytes()
    for output in self.outputs:
      result += output[0] + output[1].to_bytes(8, "little")
    return result

  def __init__(
    self,
    inputs: List[Tuple[bytes, int]],
    outputs: List[Tuple[bytes, int]],
    signature: bytes = bytes(64),
    proof: int = 0
  ) -> None:
    self.inputs = inputs
    self.outputs = outputs
    self.hash: bytes = blake2b(
      (
        b"\2" +
        len(self.inputs).to_bytes(1, "little") +
        self.serializeInputs() +
        len(self.outputs).to_bytes(1, "little") +
        self.serializeOutputs()
      ),
      digest_size=32
    ).digest()
    self.signature: bytes = signature

    self.proof: int = proof
    self.argon: bytes = SpamFilter.run(self.hash, self.proof)

  #Satisifes static typing requirements.
  @staticmethod
  def fromTransaction(
    tx: Transaction
  ) -> Any:
    return tx

  def sign(
    self,
    privKey: ed25519.SigningKey
  ) -> None:
    self.signature = privKey.sign(b"MEROS" + self.hash)

  def beat(
    self,
    spamFilter: SpamFilter
  ) -> None:
    result: Tuple[bytes, int] = spamFilter.beat(self.hash, (70 + (33 * len(self.inputs)) + (40 * len(self.outputs))) // 143)
    self.argon = result[0]
    self.proof = result[1]

  def serialize(
    self
  ) -> bytes:
    return (
      len(self.inputs).to_bytes(1, "little") +
      self.serializeInputs() +
      len(self.outputs).to_bytes(1, "little") +
      self.serializeOutputs() +
      self.signature +
      self.proof.to_bytes(4, "little")
    )

  def toJSON(
    self
  ) -> Dict[str, Any]:
    result: Dict[str, Any] = {
      "descendant": "Send",
      "inputs": [],
      "outputs": [],
      "hash": self.hash.hex().upper(),

      "signature": self.signature.hex().upper(),
      "proof": self.proof
    }
    for txInput in self.inputs:
      result["inputs"].append({
        "hash": txInput[0].hex().upper(),
        "nonce": txInput[1]
      })
    for output in self.outputs:
      result["outputs"].append({
        "key": output[0].hex().upper(),
        "amount": str(output[1])
      })
    return result

  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> Any:
    inputs: List[Tuple[bytes, int]] = []
    outputs: List[Tuple[bytes, int]] = []
    for txInput in json["inputs"]:
      inputs.append((bytes.fromhex(txInput["hash"]), txInput["nonce"]))
    for output in json["outputs"]:
      outputs.append((bytes.fromhex(output["key"]), int(output["amount"])))

    return Send(
      inputs,
      outputs,
      bytes.fromhex(json["signature"]),
      json["proof"]
    )
