#Helpers for working with Mnemonics/keys/addresses. Used by a few personal tests.

from typing import List, Tuple, Union

from hashlib import sha256

from bip_utils import Bip39WordsNum, Bip39MnemonicGenerator, Bip39SeedGenerator
from bech32 import convertbits, bech32_encode, bech32_decode

import e2e.Libs.ed25519 as ed
import e2e.Libs.BIP32 as BIP32

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


def decodeAddress(
  address: str
) -> bytes:
  decoded: Union[Tuple[None, None], Tuple[str, List[int]]] = bech32_decode(address)
  if decoded[1] is None:
    raise TestError("Decoding an invalid address.")
  res: List[int] = convertbits(decoded[1], 5, 8)
  if res[0] != 0:
    raise TestError("Decoding an address which isn't a Public Key.")
  return bytes(res[1:33])
