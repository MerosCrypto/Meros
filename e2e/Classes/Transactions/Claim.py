from typing import Dict, List, Tuple, Any
from hashlib import blake2b

from e2e.Libs.BLS import PrivateKey, Signature

from e2e.Classes.Transactions.Transaction import Transaction

class Claim(
  Transaction
):
  def serializeInputs(
    self
  ) -> bytes:
    result: bytes = len(self.inputs).to_bytes(1, "little")
    for txInput in self.inputs:
      result += txInput[0] + txInput[1].to_bytes(1, "little")
    return result

  def __init__(
    self,
    inputs: List[Tuple[bytes, int]],
    output: bytes,
    signature: bytes = Signature().serialize()
  ) -> None:
    self.inputs: List[Tuple[bytes, int]] = inputs
    self.output: bytes = output
    self.amount: int = 0
    self.hash = blake2b(
      b'\1' +
      self.serializeInputs() +
      output,
      digest_size=32
    ).digest()
    self.signature: bytes = signature

  #Satisifes static typing requirements.
  @staticmethod
  def fromTransaction(
    tx: Transaction
  ) -> Any:
    return tx

  def sign(
    self,
    privKey: PrivateKey
  ) -> None:
    self.signature = privKey.sign(self.hash).serialize()

  def serialize(
    self
  ) -> bytes:
    result: bytes = self.serializeInputs()
    result += self.output + self.signature
    return result

  def toJSON(
    self
  ) -> Dict[str, Any]:
    result: Dict[str, Any] = {
      "descendant": "Claim",
      "inputs": [],
      "outputs": [{
        "key": self.output.hex().upper(),
        "amount": str(self.amount)
      }],
      "signature": self.signature.hex().upper(),
      "hash": self.hash.hex().upper()
    }
    for txInput in self.inputs:
      result["inputs"].append({
        "hash": txInput[0].hex().upper(),
        "nonce": txInput[1]
      })
    return result

  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> Any:
    inputs: List[Tuple[bytes, int]] = []
    for txInput in json["inputs"]:
      inputs.append((bytes.fromhex(txInput["hash"]), txInput["nonce"]))

    result: Claim = Claim(
      inputs,
      bytes.fromhex(json["outputs"][0]["key"]),
      bytes.fromhex(json["signature"])
    )
    result.amount = int(json["outputs"][0]["amount"])
    return result
