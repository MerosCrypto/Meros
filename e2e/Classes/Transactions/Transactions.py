from typing import Dict, Any

from e2e.Classes.Transactions.Transaction import Transaction
from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Send import Send
from e2e.Classes.Transactions.Data import Data

class Transactions:
  def __init__(
    self
  ) -> None:
    self.txs: Dict[bytes, Transaction] = {}

  def add(
    self,
    tx: Transaction
  ) -> None:
    self.txs[tx.hash] = tx

  def toJSON(
    self
  ) -> Dict[str, Dict[str, Any]]:
    result: Dict[str, Dict[str, Any]] = {}
    for tx in self.txs:
      result[tx.hex().upper()] = self.txs[tx].toJSON()
    return result

  @staticmethod
  def fromJSON(
    json: Dict[str, Dict[str, Any]]
  ) -> "Transactions":
    result = Transactions()
    for tx in json:
      if json[tx]["descendant"] == "Claim":
        result.add(Claim.fromJSON(json[tx]))
      elif json[tx]["descendant"] == "Send":
        result.add(Send.fromJSON(json[tx]))
      elif json[tx]["descendant"] == "Data":
        result.add(Data.fromJSON(json[tx]))
      else:
        raise Exception("JSON has an unsupported Transaction type: " + json[tx]["descendant"])
    return result
