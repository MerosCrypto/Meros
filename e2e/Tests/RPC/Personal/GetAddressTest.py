#Tests getAddress primarily, yet takes the opportunity to also test getMeritHolderNick and consistency.
#Consistency is defined as consistency when rebooting the node, as well as when reloading wallets.
#Used to be part of one larger test with DerivationTest.

from typing import Dict, List, Union, Any

from time import sleep
import json

import ed25519
from pytest import raises

from e2e.Libs.BLS import PrivateKey
import e2e.Libs.ed25519 as ed
from e2e.Libs.RandomX import RandomX

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Merit.Blockchain import Block, Blockchain

from e2e.Meros.Meros import MessageType, Meros
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError, SuccessError
from e2e.Tests.RPC.Personal.Lib import getPrivateKey, getAddress, decodeAddress

def createSend(
  rpc: RPC,
  last: Union[Claim, Send],
  toAddress: str
) -> Send:
  funded: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
  if isinstance(last, Claim):
    send: Send = Send(
      [(last.hash, 0)],
      [
        (decodeAddress(toAddress), 1),
        (funded.get_verifying_key().to_bytes(), last.amount - 1)
      ]
    )
  else:
    send: Send = Send(
      [(last.hash, 1)],
      [
        (decodeAddress(toAddress), 1),
        (funded.get_verifying_key().to_bytes(), last.outputs[1][1] - 1)
      ]
    )
  send.sign(funded)
  send.beat(SpamFilter(3))
  if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
    raise TestError("Meros didn't broadcast back a Send.")
  return send

#pylint: disable=too-many-statements,too-many-locals
def GetAddressTest(
  rpc: RPC
) -> None:
  password: str = "password since it shouldn't be relevant"
  rpc.call("personal", "setWallet", {"password": password})
  mnemonic: str = rpc.call("personal", "getMnemonic")

  #Test getAddress. Doesn't test specific indexing, as that's handled by DerivationTest.
  #Not only does getAddress need to correctly derive addresses along the external chain, it needs to return new addresses.
  #That said, new is defined by use; use on the network. If it has a TX sent to it, it's used.
  #This is different than checking for UTXOs because that means any address no longer having UTXOs would be considered new again.

  expected: str = getAddress(mnemonic, password, 0)
  if rpc.call("personal", "getAddress") != expected:
    raise TestError("getAddress didn't return the next unused address (the first one).")
  #It should be returned again given it's still unused.
  if rpc.call("personal", "getAddress") != expected:
    raise TestError("getAddress didn't return the same address when there was a lack of usage.")

  #Reboot the node and verify consistency around the initial address.
  #Added due to an edge case that appeared.
  rpc.quit()
  sleep(3)
  rpc.meros = Meros(rpc.meros.db, rpc.meros.tcp, rpc.meros.rpc)
  if rpc.call("personal", "getAddress") != expected:
    raise TestError("getAddress didn't return the initial address after a reboot.")

  #Send enough Blocks to have funds available to continue testing.
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Transactions/ClaimedMint.json", "r") as file:
    vectors = json.loads(file.read())
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  def restOfTest() -> None:
    #Move expected into scope.
    expected: str = getAddress(mnemonic, password, 0)

    #Send to the new address, then call getAddress again. Verify a new address appears.
    last: Send = createSend(
      rpc,
      Claim.fromTransaction(iter(transactions.txs.values()).__next__()),
      expected
    )
    hashes: List[bytes] = [last.hash]

    expected = getAddress(mnemonic, password, 1)
    if rpc.call("personal", "getAddress") != expected:
      raise TestError("Meros didn't move to the next address once the existing one was used.")

    #Send to the new unused address, spending the funds before calling getAddress again.
    #Checks address usage isn't defined as having an UTXO, yet rather any TXO.
    #Also confirm the spending TX with full finalization before checking.
    #Ensures the TXO isn't unspent by any definition.
    last = createSend(rpc, last, expected)
    hashes.append(last.hash)

    #Spending TX.
    send: Send = Send([(hashes[-1], 0)], [(bytes(32), 1)])
    send.signature = ed.sign(
      b"MEROS" + send.hash,
      getPrivateKey(mnemonic, password, 1)
    )
    send.beat(SpamFilter(3))
    if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast back the spending Send.")
    hashes.append(send.hash)

    #In order to finalize, we need to mine 6 Blocks once this Transaction and its parent have Verifications.
    for txHash in hashes:
      sv: SignedVerification = SignedVerification(txHash)
      sv.sign(0, PrivateKey(0))
      if rpc.meros.signedElement(sv) != rpc.meros.live.recv():
        raise TestError("Meros didn't broadcast back a Verification.")

    #Close the sockets while we mine.
    rpc.meros.live.connection.close()
    rpc.meros.sync.connection.close()

    #Mine these to the Wallet on the node so we can test getMeritHolderNick.
    privKey: PrivateKey = PrivateKey(bytes.fromhex(rpc.call("personal", "getMeritHolderKey")))
    blockchain: Blockchain = Blockchain.fromJSON(vectors["blockchain"])
    for _ in range(6):
      template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", {"miner": privKey.toPublicKey().serialize().hex()})
      proof: int = -1
      tempHash: bytes = bytes()
      tempSignature: bytes = bytes()
      while (
        (proof == -1) or
        ((int.from_bytes(tempHash, "little") * (blockchain.difficulty() * 11 // 10)) > int.from_bytes(bytes.fromhex("FF" * 32), "little"))
      ):
        proof += 1
        tempHash = RandomX(bytes.fromhex(template["header"]) + proof.to_bytes(4, "little"))
        tempSignature = privKey.sign(tempHash).serialize()
        tempHash = RandomX(tempHash + tempSignature)

      rpc.call("merit", "publishBlock", {"id": template["id"], "header": template["header"] + proof.to_bytes(4, "little").hex() + tempSignature.hex()})
      blockchain.add(Block.fromJSON(rpc.call("merit", "getBlock", {"block": len(blockchain.blocks)})))

    #Verify a new address is returned.
    expected = getAddress(mnemonic, password, 2)
    if rpc.call("personal", "getAddress") != expected:
      raise TestError("Meros didn't move to the next address once the existing one was used.")

    #Get a new address after sending to the address after it.
    #Use both, and then call getAddress.
    #getAddress should detect X is used, move to Y, detect Y is used, and move to Z.
    #It shouldn't assume the next address after an used address is unused.
    #Actually has two Ys as one iteration of the code only ran for the next address; not all future addresses.

    #Send to the next next addresses.
    for i in range(2):
      addy: str = getAddress(mnemonic, password, 3 + i)

      #Reopen the sockets. This isn't done outside of the loop due to the time deriving the final address can take.
      #Due to how slow the reference Python code is, it is necessary to redo the socket connections.
      sleep(65)
      rpc.meros.liveConnect(Blockchain().blocks[0].header.hash)
      rpc.meros.syncConnect(Blockchain().blocks[0].header.hash)

      last = createSend(rpc, last, addy)
      if MessageType(rpc.meros.live.recv()[0]) != MessageType.SignedVerification:
        raise TestError("Meros didn't create and broadcast a SignedVerification for this Send.")

      if i == 0:
        #Close them again.
        rpc.meros.live.connection.close()
        rpc.meros.sync.connection.close()

    #Verify getAddress returns the existing next address.
    if rpc.call("personal", "getAddress") != expected:
      raise TestError("Sending to the address after this address caused Meros to consider this address used.")

    #Send to the next address.
    last = createSend(rpc, last, expected)
    if MessageType(rpc.meros.live.recv()[0]) != MessageType.SignedVerification:
      raise TestError("Meros didn't create and broadcast a SignedVerification for this Send.")

    #Verify getAddress returns the address after the next next addresses.
    expected = getAddress(mnemonic, password, 5)
    if rpc.call("personal", "getAddress") != expected:
      raise TestError("Meros didn't return the correct next address after using multiple addresses in a row.")

    #Now that we have mined a Block as part of this test, ensure the Merit Holder nick is set.
    if rpc.call("personal", "getMeritHolderNick") != 1:
      raise TestError("Merit Holder nick wasn't made available despite having one.")

    #Sanity check off Mnemonic.
    if rpc.call("personal", "getMnemonic") != mnemonic:
      raise TestError("getMnemonic didn't return the correct Mnemonic.")

    #Existing values used to test getMnemonic/getMeritHolderKey/getMeritHolderNick/getAccount/getAddress consistency.
    existing: Dict[str, Any] = {
      #Should be equal to the mnemonic variable, which is verified in a check above.
      "getMnemonic": rpc.call("personal", "getMnemonic"),
      "getMeritHolderKey": rpc.call("personal", "getMeritHolderKey"),
      "getMeritHolderNick": rpc.call("personal", "getMeritHolderNick"),
      "getAccount": rpc.call("personal", "getAccount"),
      #Should be equal to expected, which is also verified in a check above.
      "getAddress": rpc.call("personal", "getAddress")
    }

    #Set a new seed and verify the Merit Holder nick is cleared.
    rpc.call("personal", "setWallet")
    try:
      rpc.call("personal", "getMeritHolderNick")
      raise TestError("")
    except TestError as e:
      if str(e) != "-2 Wallet doesn't have a Merit Holder nickname assigned.":
        raise TestError("getMeritHolderNick returned something or an unexpected error when a new Mnemonic was set.")

    #Set back the old seed and verify consistency.
    rpc.call("personal", "setWallet", {"mnemonic": mnemonic, "password": password})
    for method in existing:
      if rpc.call("personal", method) != existing[method]:
        raise TestError("Setting an old seed caused the WalletDB to improperly reload.")

    #Verify calling getAddress returns the expected address.
    if rpc.call("personal", "getAddress") != expected:
      raise TestError("Meros returned an address that wasn't next after reloading the seed.")

    #Reboot the node and verify consistency.
    rpc.quit()
    sleep(3)
    rpc.meros = Meros(rpc.meros.db, rpc.meros.tcp, rpc.meros.rpc)
    for method in existing:
      if rpc.call("personal", method) != existing[method]:
        raise TestError("Rebooting the node caused the WalletDB to improperly reload.")

    #Used so Liver doesn't run its own post-test checks.
    #Since we added our own Blocks, those will fail.
    raise SuccessError()

  #Used so we don't have to write a sync loop.
  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, {8: restOfTest}).live()
