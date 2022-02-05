#Tests setWallet, getMnemonic, getMeritHolderKey, getMeritHolderNick's non-existent case, getAccount, and getAddress calls with specified indexes.
#Used to be part of one larger test with GetAddressTest.

import os
from hashlib import blake2b

from bip_utils import Bip39WordsNum, Bip39MnemonicGenerator, Bip39MnemonicValidator, Bip39SeedGenerator
import bech32ref.segwit_addr as segwit_addr

from e2e.Libs.BLS import PrivateKey
from e2e.Libs.Ristretto.Ristretto import RistrettoScalar
import e2e.Libs.HDKD as HDKD

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
  if (
    rpc.call("personal", "getMeritHolderKey") !=
    PrivateKey(blake2b(b"BLS" + seed).digest()).serialize().hex().upper()
  ):
    raise TestError("Meros generated a different Merit Holder Key.")
  #Verify getting the Merit Holder nick errors.
  try:
    rpc.call("personal", "getMeritHolderNick")
  except TestError as e:
    if e.message != "-2 Wallet doesn't have a Merit Holder nickname assigned.":
      raise TestError("getMeritHolderNick didn't error.")

  #Hash the seed with a DST for the wallet seed.
  seed = blake2b(b"Ristretto" + seed).digest()

  #Derive the first account.
  extendedKey: bytes
  chainCode: bytes
  try:
    extendedKey, chainCode = HDKD.deriveKeyAndChainCode(
      seed,
      [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31)]
    )
  except Exception:
    raise TestError("Meros gave us an invalid Mnemonic to derive (or the test generated an unusable one).")

  if rpc.call("personal", "getAccount") != {
    "key": RistrettoScalar(extendedKey).toPoint().serialize().hex().upper(),
    "chainCode": chainCode.hex().upper()
  }:
    raise TestError("Meros generated a different account public key.")

  #Also test that the correct public key is used when creating Datas.
  #It should be the first public key of the external chain for account 0.
  data: str = rpc.call("personal", "data", {"data": "a", "password": password})
  initial: Data = Data(
    bytes(32),
    RistrettoScalar(getPrivateKey(mnemonic, password, 0)).toPoint().serialize()
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
        key = HDKD.derive(
          blake2b(b"Ristretto" + Bip39SeedGenerator(mnemonic).Generate(password)).digest(),
          [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31), 0, index]
        )
        break
      except Exception:
        index += 1

    rpc.call("personal", "setWallet", {"mnemonic": mnemonic, "password": password})
    addr: str = segwit_addr.encode("mr", 1, RistrettoScalar(key).toPoint().serialize())
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
  rpc.call("personal", "getAddress", {"index": 0})
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
