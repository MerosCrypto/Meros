from typing import Dict, Any

from time import sleep
import json

import ed25519
from bech32 import convertbits, bech32_encode
from pytest import raises

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.RPC.Transactions.GetUTXOs.Lib import createSend
from e2e.Tests.Errors import TestError, SuccessError

#Should be called once already not connected to the node.
def reorgPast(
  rpc: RPC,
  mint: bytes
) -> None:
  #Mine the alt chain.
  #TODO

  #Connect back to the node.
  sleep(65)
  rpc.meros.liveConnect(Blockchain().blocks[0].header.hash)
  rpc.meros.syncConnect(Blockchain().blocks[0].header.hash)

def TGUReorgTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/RPC/Transactions/GetUTXOs.json", "r") as file:
    vectors = json.loads(file.read())
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  def actualTest() -> None:
    recipient: ed25519.SigningKey = ed25519.SigningKey(b'\1' * 32)
    recipientPub: bytes = recipient.get_verifying_key().to_bytes()
    address: str = bech32_encode("mr", convertbits(bytes([0]) + recipientPub, 8, 5))

    #Create a Send.
    send: Send = createSend(rpc, [Claim.fromJSON(vectors["olderMint"])], recipientPub)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros considered an unconfirmed Transaction's outputs as UTXOs.")

    #Spend it, with a newer Mint as an input as well so we can prune it without pruning the original.
    _: Send = createSend(rpc, [send, Claim.fromJSON(vectors["newerMint"])], bytes(32), recipient)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a Transaction's inputs as spent.")

    #Remove the spending Send by pruning its ancestor (a Mint).
    reorgPast(rpc, Claim.fromJSON(vectors["newerMint"].inputs[0][0]))
    #TODO: Meros should add back on prune, which isn't safe except when bundled with the spenders check.
    if rpc.call("transactions", "getUTXOs", {"address": address}) != [{"hash": send.hash.hex().upper(), "nonce": 0}]:
      raise TestError("Meros didn't consider a Transaction without spenders as an UTXO.")
    #Remove the original Send and verify its outputs are no longer considered UTXOs.
    reorgPast(rpc, Claim.fromJSON(vectors["olderMint"]).inputs[0][0])
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't remove the outputs of a pruned Transaction as UTXOs.")

    raise SuccessError()

  #Send Blocks so we have a Merit Holder who can instantly verify Transactions, not to mention Mints.
  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, {50: actualTest}).live()
