#Tests setMnemonic, getMnemonic, getMeritHolderKey, getMeritHolderNick, getAccountKey, and getAddress.
#AKA every route in relation to seed management.

from typing import Dict, Any

import os
from time import sleep
from hashlib import sha256

from bip_utils import Bip39WordsNum, Bip39MnemonicGenerator, Bip39MnemonicValidator, Bip39SeedGenerator
from bech32 import convertbits, bech32_encode

from e2e.Libs.BLS import PrivateKey
import e2e.Libs.ed25519 as ed
import e2e.Libs.BIP32 as BIP32

from e2e.Meros.Meros import Meros
from e2e.Meros.RPC import RPC
from e2e.Tests.Errors import TestError

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

def getAddress(
  mnemonic: str,
  password: str,
  skip: int
) -> str:
  seed: bytes = sha256(Bip39SeedGenerator(mnemonic).Generate(password)).digest()

  c: int = -1
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
    except Exception:
      continue

  return bech32_encode(
    "mr",
    convertbits(
      (
        bytes([0]) +
        ed.encodepoint(
          ed.scalarmult(ed.B, ed.decodeint(extendedKey[:32]) % ed.l)
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
    rpc.call("personal", "setMnemonic")
    verifyMnemonicAndAccountKey(rpc)

  #Set specific Mnemonics and ensure they're handled properly.
  for _ in range(10):
    mnemonic: str = getMnemonic()
    rpc.call("personal", "setMnemonic", {"mnemonic": mnemonic})
    verifyMnemonicAndAccountKey(rpc, mnemonic)

  #Create Mnemonics with passwords and ensure they're handled properly.
  for _ in range(10):
    password: str = os.urandom(32).hex()
    rpc.call("personal", "setMnemonic", {"password": password})
    verifyMnemonicAndAccountKey(rpc, password=password)

  #Set specific Mnemonics with passwords and ensure they're handled properly.
  for i in range(10):
    password: str = os.urandom(32).hex()
    #Non-hex string.
    if i == 0:
      password = "xyz"
    mnemonic: str = getMnemonic(password)
    rpc.call("personal", "setMnemonic", {"mnemonic": mnemonic, "password": password})
    verifyMnemonicAndAccountKey(rpc, mnemonic, password)

  #setMnemonic, getMnemonic, getMeritHolderKey, and getAccountKey have now been tested.
  #This leaves getAddress, checks that they all require authorization, and error cases.

  #Clear the Wallet.
  rpc.call("personal", "setMnemonic")

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

    rpc.call("personal", "setMnemonic", {"mnemonic": mnemonic, "password": password})
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

  #Send to the new address, then call getAddress again. Verify a new address appears.

  #Send to the new unused address, spending the funds before calling getAddress again.
  #Checks address usage isn't defined as having an UTXO, yet rather any TXO.
  #Also confirm the spending TX with full finalization before checking.
  #Ensures the TXO isn't unspent by any definition.

  #Get a new address after explicitly grabbing the address after it.
  #Use both, and then call getAddress.
  #getAddress should detect X is used, move to Y, detect Y is used, and move to Z.
  #It shouldn't assume the next address after an used address is unused.

  #Mine a Block to the current Wallet.

  """
  #Now that we have mined a Block, ensure the Merit Holder nick is set.
  if rpc.call("personal", "getMeritHolderNick") != 1:
    raise TestError("Merit Holder nick wasn't made available despite having one.")

  #Set a new seed and verify the Merit Holder nick is cleared.
  mnemonic = rpc.call("personal", "getMnemonic")
  rpc.call("personal", "setMnemonic")
  try:
    rpc.call("personal", "getMeritHolderNick")
  except TestError as e:
    print(e)

  #Set back the old seed and verify the Merit Holder nick is set.
  rpc.call("personal", "setMnemonic", {"mnemonic": mnemonic})
  if rpc.call("personal", "getMeritHolderNick") != 1:
    raise TestError("Merit Holder nick wasn't set when loading a mnemonic despite having one.")
  """

  #Reboot the node and ensure getMnemonic/getMeritHolderKey/getMeritHolderNick/getAccountKey/getAddress consistency.
  existing: Dict[str, Any] = {
    "getMnemonic": rpc.call("personal", "getMnemonic"),
    "getMeritHolderKey": rpc.call("personal", "getMeritHolderKey"),
    #TODO: "getMeritHolderNick": rpc.call("personal", "getMeritHolderNick"),
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

  #Test a Mnemonic with an improper amount of entropy.

  #Negative index to getAddress.
