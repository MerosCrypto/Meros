from typing import Dict, List, Tuple, Any

from e2e.Classes.Transactions.Transaction import Transaction

class Mint(
  Transaction
):
  def __init__(
    self,
    blockHash: bytes,
    outputs: List[Tuple[int, int]]
  ) -> None:
    self.outputs: List[Tuple[int, int]] = outputs
    self.hash = blockHash

  #Satisifes static typing requirements.
  @staticmethod
  def fromTransaction(
    tx: Transaction
  ) -> Any:
    return tx

  def serialize(
    self
  ) -> bytes:
    raise Exception("Mint serialize called.")

  def toJSON(
    self
  ) -> Dict[str, Any]:
    result: Dict[str, Any] = {
      "descendant": "Mint",
      "inputs": [],
      "outputs": [],
      "hash": self.hash.hex().upper()
    }
    for output in self.outputs:
      result["outputs"].append({
        "nick": output[0],
        "amount": str(output[1])
      })
    return result

  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> "Mint":
    outputs: List[Tuple[int, int]] = []
    for output in json["outputs"]:
      outputs.append((output["nick"], int(output["amount"])))
    return Mint(bytes.fromhex(json["hash"]), outputs)
