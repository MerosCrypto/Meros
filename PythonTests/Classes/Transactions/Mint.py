#Types.
from typing import Dict, List, Tuple, Any

#Transaction and SpamFilter classes.
from PythonTests.Classes.Transactions.Transaction import Transaction

#Mint class.
class Mint(
  Transaction
):
  #Constructor.
  def __init__(
    self,
    blockHash: bytes,
    outputs: List[Tuple[int, int]]
  ) -> None:
    self.outputs: List[Tuple[int, int]] = outputs
    self.hash = blockHash

  #Transaction -> Mint. Satisifes static typing requirements.
  @staticmethod
  def fromTransaction(
    tx: Transaction
  ) -> Any:
    return tx

  #Serialize.
  def serialize(
    self
  ) -> bytes:
    raise Exception("Mint serialize called.")

  #Mint -> JSON.
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
        "key": output[0],
        "amount": str(output[1])
      })
    return result

  #JSON -> Mint.
  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> Any:
    outputs: List[Tuple[int, int]] = []
    for output in json["outputs"]:
      outputs.append((output["key"], int(output["amount"])))

    return Mint(bytes.fromhex(json["hash"]), outputs)
