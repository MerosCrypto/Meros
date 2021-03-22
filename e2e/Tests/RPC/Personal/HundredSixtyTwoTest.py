from typing import Dict, Any

from e2e.Meros.RPC import RPC
from e2e.Tests.Errors import TestError

def HundredSixtyTwoTest(
  rpc: RPC
) -> None:
  #Create the first Datas.
  mnemonic: str = rpc.call("personal", "getMnemonic")
  abcData: str = rpc.call("personal", "data", {"data": "abc"})

  #Create a Data on a different account.
  rpc.call("personal", "setWallet")
  defData: str = rpc.call("personal", "data", {"data": "def"})

  #Verify the def Data was created.
  if rpc.call("transactions", "getTransaction", {"hash": defData})["descendant"] != "Data":
    raise TestError("Meros didn't create a Data for an imported account when the existing account had Datas.")

  #Switch back to the old Mnemonic.
  rpc.call("personal", "setWallet", {"mnemonic": mnemonic})

  #Ensure we can create new Datas on it as well, meaning switching to a Mnemonic ports the chain.
  ghiDataHash: str = rpc.call("personal", "data", {"data": "ghi"})
  ghiData: Dict[str, Any] = rpc.call("transactions", "getTransaction", {"hash": ghiDataHash})
  del ghiData["signature"]
  del ghiData["proof"]
  if ghiData != {
    "descendant": "Data",
    "inputs": [{
      "hash": abcData
    }],
    "outputs": [],
    "hash": ghiDataHash,
    "data": b"ghi".hex()
  }:
    raise TestError("Data created for an imported account with Datas isn't correct.")
