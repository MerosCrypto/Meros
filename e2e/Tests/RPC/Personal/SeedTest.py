#Tests setWallet, getMnemonic, getMeritHolderKey, getMeritHolderNick, getAccountKey, and getAddress.
#AKA every route in relation to seed management.

from typing import Dict, List, Tuple, Union, Any

import os
from time import sleep
from hashlib import sha256
import json

import ed25519
from bip_utils import Bip39WordsNum, Bip39MnemonicGenerator, Bip39MnemonicValidator, Bip39SeedGenerator
from bech32 import convertbits, bech32_encode, bech32_decode
from pytest import raises

from e2e.Libs.BLS import PrivateKey
import e2e.Libs.ed25519 as ed
import e2e.Libs.BIP32 as BIP32
from e2e.Libs.RandomX import RandomX

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Merit.Blockchain import Block, Blockchain

from e2e.Meros.Meros import Meros
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Tests.Errors import TestError, SuccessError

def bech32Decode(
  address: str
) -> bytes:
  res: Union[Tuple[None, None], Tuple[str, List[int]]] = bech32_decode(address)
  if res[1] is None:
    raise TestError("Decoding an invalid address.")
  return bytes(convertbits(res[1], 5, 8))[1:33]

def getMnemonic(
  password: str = ""
) -> str:
  while True:
    res: str = Bip39MnemonicGenerator.FromWordsNumber(Bip39WordsNum.WORDS_NUM_24)
    seed: bytes = sha256(Bip39SeedGenerator(res).Generate(password)).digest()
    try:
      BIP32.derive(seed, [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31), 0])
      BIP32.derive(seed, [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31), 1])
    except Exception:
      continue
    return res

def getPrivateKey(
  mnemonic: str,
  password: str,
  skip: int
) -> bytes:
  seed: bytes = sha256(Bip39SeedGenerator(mnemonic).Generate(password)).digest()

  c: int = -1
  failures: int = 0
  extendedKey: bytes = bytes()
  while skip != -1:
    c += 1
    try:
      extendedKey = BIP32.derive(
        seed,
        [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31), 1, c]
      )

      #Since we derived a valid address, decrement skip.
      skip -= 1
      failures = 0
    except Exception:
      #Safety check to prevent infinite execution.
      failures += 1
      if failures == 100:
        raise Exception("Invalid mnemonic passed to getPrivateKey.")
      continue

  return extendedKey

def getAddress(
  mnemonic: str,
  password: str,
  skip: int
) -> str:
  return bech32_encode(
    "mr",
    convertbits(
      (
        bytes([0]) +
        ed.encodepoint(
          ed.scalarmult(ed.B, ed.decodeint(getPrivateKey(mnemonic, password, skip)[:32]) % ed.l)
        )
      ),
      8,
      5
    )
  )

def verifyMnemonicAndAccountKey(
  rpc: RPC,
  mnemonic: str = "",
  password: str = ""
) -> None:
  #If a Mnemonic wasn't specified, grab the node's.
  if mnemonic == "":
    mnemonic = rpc.call("personal", "getMnemonic")

  #Verify Mnemonic equivalence.
  if mnemonic != rpc.call("personal", "getMnemonic"):
    raise TestError("Node had a different Mnemonic.")

  #Validate it.
  if not Bip39MnemonicValidator(mnemonic).Validate():
    raise TestError("Mnemonic checksum was incorrect.")

  #Verify derivation from seed to wallet.
  seed: bytes = Bip39SeedGenerator(mnemonic).Generate(password)
  #Check the Merit Holder key.
  if rpc.call("personal", "getMeritHolderKey") != PrivateKey(seed[:32]).serialize().hex().upper():
    raise TestError("Meros generated a different Merit Holder Key.")
  #Verify getting the Merit Holder nick errors.
  try:
    rpc.call("personal", "getMeritHolderNick")
  except TestError as e:
    if e.message != "-2 Wallet doesn't have a Merit Holder nickname assigned.":
      raise TestError("getMeritHolderNick didn't error.")

  #Hash the seed again for the wallet seed (first is the Merit Holder seed).
  seed = sha256(seed).digest()

  #Derive the first account.
  extendedKey: bytes
  try:
    extendedKey = BIP32.derive(
      seed,
      [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31)]
    )
  except Exception:
    raise TestError("Meros gave us an invalid Mnemonic to derive (or the test generated an unusable one).")

  #For some reason, pylint decided to add in detection of stdlib members.
  #It doesn't do it properly, and thinks encodepoint returns a string.
  #It returns bytes, which does have hex as a method.
  #pylint: disable=no-member
  if ed.encodepoint(
    ed.scalarmult(ed.B, ed.decodeint(extendedKey[:32]) % ed.l)
  ).hex().upper() != rpc.call("personal", "getAccountKey"):
    #The Nim tests ensure accurate BIP 32 derivation thanks to vectors.
    #That leaves BIP39/44 in the air.
    #This isn't technically true due to an ambiguity/the implementation we used the vectors of, yet it's true enough for this comment.
    raise TestError("Meros generated a different parent public key.")

def SeedTest(
  rpc: RPC
) -> None:
  #Start by testing BIP 32, 39, and 44 functionality in general.
  for _ in range(10):
    rpc.call("personal", "setWallet")
    verifyMnemonicAndAccountKey(rpc)

  #Set specific Mnemonics and ensure they're handled properly.
  for _ in range(10):
    mnemonic: str = getMnemonic()
    rpc.call("personal", "setWallet", {"mnemonic": mnemonic})
    verifyMnemonicAndAccountKey(rpc, mnemonic)

  #Create Mnemonics with passwords and ensure they're handled properly.
  for _ in range(10):
    password: str = os.urandom(32).hex()
    rpc.call("personal", "setWallet", {"password": password})
    verifyMnemonicAndAccountKey(rpc, password=password)

  #Set specific Mnemonics with passwords and ensure they're handled properly.
  for i in range(10):
    password: str = os.urandom(32).hex()
    #Non-hex string.
    if i == 0:
      password = "xyz"
    mnemonic: str = getMnemonic(password)
    rpc.call("personal", "setWallet", {"mnemonic": mnemonic, "password": password})
    verifyMnemonicAndAccountKey(rpc, mnemonic, password)

  #setWallet, getMnemonic, getMeritHolderKey, and getAccountKey have now been tested.
  #This leaves getAddress, checks that they all require authorization, and error cases.

  #Clear the Wallet.
  rpc.call("personal", "setWallet")

  #Test getAddress.
  #Not only does it need to correctly derive addresses along the external chain, it needs to return new addresses.
  #That said, new is defined by use; use on the network. If it has a TX sent to it, it's used.
  #This is different than checking for UTXOs because that means any address no longer having UTXOs would be considered new.

  #Start by testing specific derivation.
  password: str = "password since it shouldn't be relevant"
  for _ in range(10):
    mnemonic: str = getMnemonic(password)
    index: int = 100
    key: bytes
    while True:
      try:
        key = BIP32.derive(
          sha256(Bip39SeedGenerator(mnemonic).Generate(password)).digest(),
          [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31), 1, index]
        )
        break
      except Exception:
        index += 1

    rpc.call("personal", "setWallet", {"mnemonic": mnemonic, "password": password})
    addr: str = bech32_encode(
      "mr",
      convertbits(
        (
          bytes([0]) +
          ed.encodepoint(ed.scalarmult(ed.B, ed.decodeint(key[:32]) % ed.l))
        ),
        8,
        5
      )
    )
    if rpc.call("personal", "getAddress", {"index": index}) != addr:
      raise TestError("Didn't get the correct address for this index.")

  #Test new address generation.
  expected: str = getAddress(rpc.call("personal", "getMnemonic"), password, 0)
  if rpc.call("personal", "getAddress") != expected:
    raise TestError("getAddress didn't return the next unused address (the first one).")
  #It should be returned again given it's still unused.
  if rpc.call("personal", "getAddress") != expected:
    raise TestError("getAddress didn't return the same address when there was a lack of usage.")

  #Send enough Blocks to have funds available to continue testing.
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Transactions/ClaimedMint.json", "r") as file:
    vectors = json.loads(file.read())
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  def restOfTest() -> None:
    #Move expected into scope.
    expected: str = getAddress(rpc.call("personal", "getMnemonic"), password, 0)

    #Send to the new address, then call getAddress again. Verify a new address appears.
    funded: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
    claim: Claim = Claim.fromTransaction(iter(transactions.txs.values()).__next__())
    send: Send = Send(
      [(claim.hash, 0)],
      [
        (bech32Decode(expected), 1),
        (funded.get_verifying_key().to_bytes(), claim.amount - 1)
      ]
    )
    send.sign(funded)
    send.beat(SpamFilter(3))
    if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast back the first Send.")
    hashes: List[bytes] = [send.hash]

    expected = getAddress(rpc.call("personal", "getMnemonic"), password, 1)
    if rpc.call("personal", "getAddress") != expected:
      raise TestError("Meros didn't move to the next address once the existing one was used.")

    #Send to the new unused address, spending the funds before calling getAddress again.
    #Checks address usage isn't defined as having an UTXO, yet rather any TXO.
    #Also confirm the spending TX with full finalization before checking.
    #Ensures the TXO isn't unspent by any definition.
    send = Send(
      [(send.hash, 1)],
      [
        (bech32Decode(expected), 1),
        (funded.get_verifying_key().to_bytes(), (claim.amount - 1) - 1)
      ]
    )
    send.sign(funded)
    send.beat(SpamFilter(3))
    if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast back the second Send.")
    hashes.append(send.hash)

    #Spending TX.
    send = Send([(send.hash, 0)], [(funded.get_verifying_key().to_bytes(), 1)])
    send.signature = ed.sign(
      b"MEROS" + send.hash,
      getPrivateKey(rpc.call("personal", "getMnemonic"), password, 1)
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
    expected = getAddress(rpc.call("personal", "getMnemonic"), password, 2)
    if rpc.call("personal", "getAddress") != expected:
      raise TestError("Meros didn't move to the next address once the existing one was used.")

    #Get a new address after sending to the address after it.
    #Use both, and then call getAddress.
    #getAddress should detect X is used, move to Y, detect Y is used, and move to Z.
    #It shouldn't assume the next address after an used address is unused.
    #TODO

    #Now that we have mined a Block, ensure the Merit Holder nick is set.
    if rpc.call("personal", "getMeritHolderNick") != 1:
      raise TestError("Merit Holder nick wasn't made available despite having one.")

    expected = rpc.call("personal", "getAddress")

    #Set a new seed and verify the Merit Holder nick is cleared.
    mnemonic = rpc.call("personal", "getMnemonic")
    rpc.call("personal", "setWallet")
    try:
      rpc.call("personal", "getMeritHolderNick")
      raise TestError("")
    except TestError as e:
      if str(e) != "-2 Wallet doesn't have a Merit Holder nickname assigned.":
        raise TestError("getMeritHolderNick returned something or an unexpected error when a new Mnemonic was set.")

    #Set back the old seed and verify the Merit Holder nick is set.
    rpc.call("personal", "setWallet", {"mnemonic": mnemonic, "password": password})
    if rpc.call("personal", "getMeritHolderNick") != 1:
      raise TestError("Merit Holder nick wasn't set when loading a mnemonic despite having one.")

    #Verify calling getAddress returns the expected address.
    if rpc.call("personal", "getAddress") != expected:
      raise TestError("Meros returned an address that wasn't next after reloading the seed.")

    #Reboot the node and ensure getMnemonic/getMeritHolderKey/getMeritHolderNick/getAccountKey/getAddress consistency.
    existing: Dict[str, Any] = {
      "getMnemonic": rpc.call("personal", "getMnemonic"),
      "getMeritHolderKey": rpc.call("personal", "getMeritHolderKey"),
      "getMeritHolderNick": rpc.call("personal", "getMeritHolderNick"),
      "getAccountKey": rpc.call("personal", "getAccountKey"),
      "getAddress": rpc.call("personal", "getAddress")
    }
    rpc.quit()
    sleep(3)
    rpc.meros = Meros(rpc.meros.db, rpc.meros.tcp, rpc.meros.rpc)
    for method in existing:
      if rpc.call("personal", method) != existing[method]:
        raise TestError("Rebooting the node caused the WalletDB to improperly reload.")

    #Test all these methods require authorization.
    #TODO

    #Test a Mnemonic with an improper amount of entropy.
    #TODO

    #Negative index to getAddress.
    #TODO

    #Used so Liver doesn't run its own post-test checks.
    raise SuccessError()

  #Used so we don't have to write a sync loop.
  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, {8: restOfTest}).live()
