#Tests setWallet, getMnemonic, getMeritHolderKey, getMeritHolderNick's non-existent case, getAccount, and getAddress calls with specified indexes.
#Used to be part of one larger test with GetAddressTest.

import os
from hashlib import sha256

from bip_utils import Bip39WordsNum, Bip39MnemonicGenerator, Bip39MnemonicValidator, Bip39SeedGenerator
from bech32 import convertbits, bech32_encode

from e2e.Libs.BLS import PrivateKey
import e2e.Libs.Ristretto.ed25519 as ed
import e2e.Libs.BIP32 as BIP32

from e2e.Classes.Transactions.Transactions import Data

from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError
from e2e.Tests.RPC.Personal.Lib import getMnemonic, getPrivateKey

def verifyMnemonicAndAccount(
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
  chainCode: bytes
  try:
    extendedKey, chainCode = BIP32.deriveKeyAndChainCode(
      seed,
      [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31)]
    )
  except Exception:
    raise TestError("Meros gave us an invalid Mnemonic to derive (or the test generated an unusable one).")

  #For some reason, pylint decided to add in detection of stdlib members.
  #It doesn't do it properly, and thinks encodepoint returns a string.
  #It returns bytes, which does have hex as a method.
  #pylint: disable=no-member
  if rpc.call("personal", "getAccount") != {
    "key": ed.Ed25519Scalar(extendedKey[:32]).toPoint().serialize().hex().upper(),
    "chainCode": chainCode.hex().upper()
  }:
    #The Nim tests ensure accurate BIP 32 derivation thanks to vectors.
    #That leaves BIP 39/44 in the air.
    #This isn't technically true due to an ambiguity/the implementation we used the vectors of, yet it's true enough for this comment.
    raise TestError("Meros generated a different account public key.")

  #Also test that the correct public key is used when creating Datas.
  #It should be the first public key of the external chain for account 0.
  data: str = rpc.call("personal", "data", {"data": "a", "password": password})
  initial: Data = Data(
    bytes(32),
    ed.Ed25519Scalar(getPrivateKey(mnemonic, password, 0)[:32]).toPoint().serialize()
  )
  #Checks via the initial Data.
  if bytes.fromhex(rpc.call("transactions", "getTransaction", {"hash": data})["inputs"][0]["hash"]) != initial.hash:
    raise TestError("Meros used the wrong key to create the Data Transactions.")

#pylint: disable=too-many-statements
def DerivationTest(
  rpc: RPC
) -> None:
  #Start by testing BIP 32, 39, and 44 functionality in general.
  for _ in range(10):
    rpc.call("personal", "setWallet")
    verifyMnemonicAndAccount(rpc)

  #Set specific Mnemonics and ensure they're handled properly.
  for _ in range(10):
    mnemonic: str = getMnemonic()
    rpc.call("personal", "setWallet", {"mnemonic": mnemonic})
    verifyMnemonicAndAccount(rpc, mnemonic)

  #Create Mnemonics with passwords and ensure they're handled properly.
  for _ in range(10):
    password: str = os.urandom(32).hex()
    rpc.call("personal", "setWallet", {"password": password})
    verifyMnemonicAndAccount(rpc, password=password)

  #Set specific Mnemonics with passwords and ensure they're handled properly.
  for i in range(10):
    password: str = os.urandom(32).hex()
    #Non-hex string.
    if i == 0:
      password = "xyz"
    mnemonic: str = getMnemonic(password)
    rpc.call("personal", "setWallet", {"mnemonic": mnemonic, "password": password})
    verifyMnemonicAndAccount(rpc, mnemonic, password)

  #setWallet, getMnemonic, getMeritHolderKey, getMeritHolderNick's non-existent case, and getAccount have now been tested.
  #This leaves getAddress with specific indexes.

  #Clear the Wallet.
  rpc.call("personal", "setWallet")

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
          [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31), 0, index]
        )
        break
      except Exception:
        index += 1

    rpc.call("personal", "setWallet", {"mnemonic": mnemonic, "password": password})
    addr: str = bech32_encode(
      "mr",
      convertbits(
        bytes([0]) + ed.Ed25519Scalar(key[:32]).toPoint().serialize(),
        8,
        5
      )
    )
    if rpc.call("personal", "getAddress", {"index": index}) != addr:
      raise TestError("Didn't get the correct address for this index.")

  #Test if a specific address is requested, it won't come up naturally.
  #This isn't explicitly required by the RPC spec, which has been worded carefully to leave this open ended.
  #The only requirement is the address was never funded and the index is sequential (no moving backwards).
  #The node offers this feature to try to make mixing implicit/explicit addresses safer, along with some internal benefits.
  #That said, said internal benefits are minimal or questionable, hence why the RPC docs are open ended.
  #This way we can decide differently in the future.
  rpc.call("personal", "setWallet")
  firstAddr: str = rpc.call("personal", "getAddress")
  #Explicitly get the first address.
  for i in range(256):
    try:
      rpc.call("personal", "getAddress", {"index": i})
      break
    except TestError:
      if i == 255:
        raise Exception("The first 256 address were invalid; this should be practically impossible.")
  if firstAddr == rpc.call("personal", "getAddress"):
    raise TestError("Explicitly grabbed address was naturally returned.")

  #Test error cases.

  #Mnemonic with an improper amount of entropy.
  #Runs multiple times in case the below error pops up for the sole reason the Mnemonic didn't have viable keys.
  #This should error earlier than that though.
  for _ in range(16):
    try:
      rpc.call(
        "personal",
        "setWallet",
        {
          "mnemonic": Bip39MnemonicGenerator.FromWordsNumber(Bip39WordsNum.WORDS_NUM_12)
        }
      )
      raise Exception()
    except Exception as e:
      if str(e) != "-3 Invalid mnemonic or password.":
        raise TestError("Could set a Mnemonic with too little entropy.")

  #Mnemonic with additional spaces.
  rpc.call("personal", "setWallet")
  mnemonic: str = rpc.call("personal", "getMnemonic")
  rpc.call("personal", "setWallet", {"mnemonic": "   " + (" " * 2).join(mnemonic.split(" ")) + " "})
  if rpc.call("personal", "getMnemonic") != mnemonic:
    raise TestError("Meros didn't handle a mnemonic with extra whitespace.")

  #Negative index to getAddress.
  try:
    rpc.call("personal", "getAddress", {"index": -1})
    raise Exception()
  except Exception as e:
    if str(e) != "-32602 Invalid params.":
      raise TestError("Could call getAddress with a negative index.")
