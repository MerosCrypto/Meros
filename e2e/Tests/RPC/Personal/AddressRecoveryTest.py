#Tests address recovery when reloading seeds, and does so via personal_getUTXOs.
#Therefore also tests personal_getUTXOs, which just iterates over transactions_getUTXOs which is thoroughly tested.
#Hence why it is not more thoroughly tested, though this is comprehensive enough.
#Arguably, this should be the personal_getUTXOs test with address recovery also tested.
#As one other note, this test excessively uses sleep. For some reason, things that shouldn't take 20+ seconds do.
#Instead of debugging this for a faster runtime, the quick and easy solution was taken.
#This should be improved.

from typing import Dict, List, Union, Any

from time import sleep
import json

from pytest import raises

import e2e.Libs.Ristretto.Ristretto as Ristretto
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.Meros import Meros
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.RPC.Transactions.GetUTXOs.Lib import mineBlock
from e2e.Tests.RPC.Personal.Lib import getAddress, decodeAddress
from e2e.Tests.Errors import TestError, SuccessError

def createSend(
  rpc: RPC,
  last: Union[Claim, Send],
  toAddress: str
) -> Send:
  funded: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
  if isinstance(last, Claim):
    send: Send = Send(
      [(last.hash, 0)],
      [
        (decodeAddress(toAddress), 1),
        (funded.get_verifying_key(), last.amount - 1)
      ]
    )
  else:
    send: Send = Send(
      [(last.hash, 1)],
      [
        (decodeAddress(toAddress), 1),
        (funded.get_verifying_key(), last.outputs[1][1] - 1)
      ]
    )

  send.sign(funded)
  send.beat(SpamFilter(3))
  sleep(65)
  rpc.meros.liveConnect(Blockchain().blocks[0].header.hash)
  if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
    raise TestError("Meros didn't broadcast back a Send.")

  sv: SignedVerification = SignedVerification(send.hash)
  sv.sign(0, PrivateKey(0))
  if rpc.meros.signedElement(sv) != rpc.meros.live.recv():
    raise TestError("Meros didn't broadcast back a Verification.")

  return send

def sortUTXOs(
  utxos: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
  return sorted(utxos, key=lambda utxo: utxo["hash"])

#pylint: disable=too-many-statements
def AddressRecoveryTest(
  rpc: RPC
) -> None:
  mnemonic: str = rpc.call("personal", "getMnemonic")

  vectors: Dict[str, Any]
  with open("e2e/Vectors/RPC/Transactions/GetUTXOs.json", "r") as file:
    vectors = json.loads(file.read())
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  def test() -> None:
    #Send to the new address and get the next address.
    dest: str = rpc.call("personal", "getAddress")
    last: Send = createSend(rpc, Claim.fromJSON(vectors["newerMintClaim"]), dest)

    utxos: List[Dict[str, Any]] = rpc.call("personal", "getUTXOs")
    if utxos != [{"address": dest, "hash": last.hash.hex().upper(), "nonce": 0}]:
      raise TestError("personal_getUTXOs didn't return the correct UTXOs.")

    #Set a different mnemonic to verify the tracked addresses is cleared.
    rpc.call("personal", "setWallet")
    if rpc.call("personal", "getUTXOs") != []:
      raise TestError("Setting a new Mnemonic didn't clear the tracked addresses.")

    #Reload the Mnemonic and verify the UTXOs are correct.
    rpc.call("personal", "setWallet", {"mnemonic": mnemonic})
    if sortUTXOs(rpc.call("personal", "getUTXOs")) != sortUTXOs(utxos):
      #This error message points out how no addresses are really being discovered yet; this is account zero's address.
      #That said, if the test started at the next address, there'd be a gap.
      #As that's an extra factor, this is tested before gaps are.
      raise TestError("Meros didn't recover the very first address.")

    #Now send to the next address and check accuracy.
    dest = rpc.call("personal", "getAddress")
    last = createSend(rpc, last, dest)
    utxos.append({"address": dest, "hash": last.hash.hex().upper(), "nonce": 0})
    if sortUTXOs(rpc.call("personal", "getUTXOs")) != sortUTXOs(utxos):
      raise TestError("Meros didn't track an implicitly gotten address.")
    rpc.call("personal", "setWallet", {"mnemonic": mnemonic})
    if sortUTXOs(rpc.call("personal", "getUTXOs")) != sortUTXOs(utxos):
      raise TestError("Meros didn't recover the first address after the initial address.")

    #Send funds to the address after the next address; tests a gap when discovering addresses.
    last = createSend(rpc, last, getAddress(mnemonic, "", 3))
    if sortUTXOs(rpc.call("personal", "getUTXOs")) != sortUTXOs(utxos):
      raise TestError("Meros magically recognized UTXOs as belonging to this Wallet or someone implemented an address cache.")
    utxos.append({"address": getAddress(mnemonic, "", 3), "hash": last.hash.hex().upper(), "nonce": 0})
    rpc.call("personal", "setWallet", {"mnemonic": mnemonic})
    if sortUTXOs(rpc.call("personal", "getUTXOs")) != sortUTXOs(utxos):
      raise TestError("Meros didn't discover a used address in the Wallet when there was a gap.")

    #Finally, anything 10+ unused addresses out shouldn't be recovered.
    last = createSend(rpc, last, getAddress(mnemonic, "", 14))
    rpc.call("personal", "setWallet", {"mnemonic": mnemonic})
    if sortUTXOs(rpc.call("personal", "getUTXOs")) != sortUTXOs(utxos):
      raise TestError("Meros recovered an address's UTXOs despite it being 10 unused addresses out.")

    #Explicitly generating this address should start tracking it though.
    rpc.call("personal", "getAddress", {"index": 14})
    utxos.append({"address": getAddress(mnemonic, "", 14), "hash": last.hash.hex().upper(), "nonce": 0})
    if sortUTXOs(rpc.call("personal", "getUTXOs")) != sortUTXOs(utxos):
      raise TestError("personal_getUTXOs didn't track an address explicitly indexed.")

    #If asked for an address, Meros should return the 5th (skip 4).
    #It's the first unused address AFTER used addresss EXCEPT ones explicitly requested.
    #This can, in the future, be juwst the first unused address/include ones explicitly requested (see DerivationTest for commentary on that).
    #This is really meant to ensure consistent behavior until we properly decide otherwise.
    if rpc.call("personal", "getAddress") != getAddress(mnemonic, "", 4):
      raise TestError("Meros didn't return the next unused address (with conditions; see comment).")

    #Mine a Block to flush the Transactions and Verifications to disk.
    sleep(65)
    rpc.meros.liveConnect(Blockchain().blocks[0].header.hash)
    mineBlock(rpc)

    #Existing values used to test getAddress/getUTXOs consistency.
    #The former is thoroughly tested elsewhere, making it quite redundant.
    existing: Dict[str, Any] = {
      "getAddress": rpc.call("personal", "getAddress"),
      "getUTXOs": rpc.call("personal", "getUTXOs")
    }

    #Reboot the node and verify consistency.
    rpc.quit()
    sleep(3)
    rpc.meros = Meros(rpc.meros.db, rpc.meros.tcp, rpc.meros.rpc)
    if sortUTXOs(rpc.call("personal", "getUTXOs")) != sortUTXOs(existing["getUTXOs"]):
      raise TestError("Rebooting the node caused the WalletDB to improperly reload UTXOs.")
    if rpc.call("personal", "getAddress") != existing["getAddress"]:
      raise TestError("Rebooting the node caused the WalletDB to improperly reload the next address.")

    #Used so Liver doesn't run its own post-test checks.
    #Since we added our own Blocks, those will fail.
    raise SuccessError()

  #Used so we don't have to write a sync loop.
  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, {50: test}).live()
