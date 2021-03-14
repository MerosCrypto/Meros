#Tests setMnemonic, getMnemonic, getMeritHolderKey, getMeritHolderNick, getParentPublicKey, and getAddress.
#AKA every route in relation to seed management.

import os
from hashlib import blake2b
from bip_utils import Bip39WordsNum, Bip39MnemonicGenerator, Bip39MnemonicValidator, Bip39SeedGenerator

from e2e.Libs.BLS import PrivateKey
import e2e.Libs.ed25519 as ed
import e2e.Libs.BIP32 as BIP32

from e2e.Meros.RPC import RPC
from e2e.Tests.Errors import TestError

def verifyMnemonicAndParentPublicKey(
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
  if rpc.call("personal", "getMeritHolderKey") != PrivateKey(seed):
    raise TestError("Meros generated a different Merit Holder Key.")
  #Verify getting the Merit Holder nick errors.
  try:
    rpc.call("personal", "getMeritHolderNick")
  except TestError as e:
    print(e)

  #Hash the seed again for the wallet seed (first is the Merit Holder seed).
  seed = blake2b(seed, digest_size=32).digest()

  #Derive the first account.
  extendedKey: bytes = BIP32.derive(seed, [0])
  if ed.encodepoint(
    ed.scalarmult(ed.B, ed.decodeint(extendedKey[:32]) % ed.l)
  ).hex().upper() != rpc.call("personal", "getParentPublicKey"):
    #The Nim tests ensure accurate BIP 32 derivation thanks to vectors.
    #That leaves BIP39/44 in the air.
    raise TestError("Meros generated a different parent public key.")

def SeedTest(
  rpc: RPC
) -> None:
  #Start by testing BIP 32, 39, and 44 functionality in general.
  for _ in range(100):
    rpc.call("personal", "setMnemonic")
    verifyMnemonicAndParentPublicKey(rpc)

  #Set specific Mnemonics and ensure they're handled properly.
  for _ in range(100):
    mnemonic: str = Bip39MnemonicGenerator.FromWordsNumber(Bip39WordsNum.WORDS_NUM_24)
    rpc.call("personal", "setMnemonic", {"mnemonic": mnemonic})
    verifyMnemonicAndParentPublicKey(rpc, mnemonic)

  #Create Mnemonics with passwords and ensure they're handled properly.
  for _ in range(100):
    password: str = os.urandom(32).hex()
    rpc.call("personal", "setMnemonic", {"password": password})
    verifyMnemonicAndParentPublicKey(rpc, password=password)

  #Set specific Mnemonics with passwords and ensure they're handled properly.
  for i in range(100):
    mnemonic: str = Bip39MnemonicGenerator.FromWordsNumber(Bip39WordsNum.WORDS_NUM_24)
    password: str = os.urandom(32).hex()
    #Non-hex string.
    if i == 0:
      password = "xyz"
    rpc.call("personal", "setMnemonic", {"mnemonic": mnemonic, "password": password})
    verifyMnemonicAndParentPublicKey(rpc, mnemonic, password)

  #setMnemonic, getMnemonic, getMeritHolderKey, and getParentPublicKey have now been tested.
  #This leaves getAddress, checks that they all require authorization, and error cases.

  #Test getAddress.
  #Not only does it need to correctly derive addresses along the external chain, it needs to return new addresses.
  #That said, new is defined by use; use on the network. If it has a TX sent to it, it's used.
  #This is different than checking for UTXOs because that means any address no longer having UTXOs would be considered new.

  #getAddress.
  #getAddress returns the same.
  #Sending to it causes a new address to be returned.

  #Send to the new address, then spend it, then call getAddress again. Verify a new address appears.
  #Confirm the spending TX with full finalization before checking.

  """
  #Now that we have mined a Block as part of the above, ensure the Merit Holder nick is set.
  if rpc.call("personal", "getMeritHolderNick") != 0:
    raise TestError("Merit Holder nick wasn't made available despite having one.")

  #Set a new seed and verify the Merit Holder nick is cleared.
  rpc.call("personal", "setMnemonic")
  try:
    rpc.call("personal", "getMeritHolderNick")
  except TestError as e:
    print(e)
  """

  #Test all these methods require authorization.
  #Test a Mnemonic with an improper amount of entropy.
  #Negative index to getAddress.
