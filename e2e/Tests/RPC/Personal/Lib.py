#Helpers for working with Mnemonics/keys/addresses. Used by a few personal tests.

from typing import List, Tuple, Union

from hashlib import blake2b

from bip_utils import Bip39WordsNum, Bip39MnemonicGenerator, Bip39SeedGenerator
from bech32ref.segwit_addr import Encoding, convertbits, bech32_encode, bech32_decode

from e2e.Libs.Ristretto.Ristretto import RistrettoScalar
import e2e.Libs.HDKD as HDKD

from e2e.Tests.Errors import TestError

def getMnemonic(
  password: str = ""
) -> str:
  while True:
    res: str = Bip39MnemonicGenerator.FromWordsNumber(Bip39WordsNum.WORDS_NUM_24)
    seed: bytes = blake2b(b"Ristretto" + Bip39SeedGenerator(res).Generate(password)).digest()
    try:
      HDKD.derive(seed, [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31), 0])
      HDKD.derive(seed, [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31), 1])
    except Exception:
      continue
    return res

def getPrivateKey(
  mnemonic: str,
  password: str,
  index: int
) -> bytes:
  seed: bytes = blake2b(b"Ristretto" + Bip39SeedGenerator(mnemonic).Generate(password)).digest()
  return HDKD.derive(
    seed,
    [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31), 0, index]
  )

def getPublicKey(
  mnemonic: str,
  password: str,
  index: int
) -> bytes:
  return RistrettoScalar(getPrivateKey(mnemonic, password, index)).toPoint().serialize()

def getChangePublicKey(
  mnemonic: str,
  password: str,
  index: int
) -> bytes:
  return RistrettoScalar(
    HDKD.derive(
      blake2b(b"Ristretto" + Bip39SeedGenerator(mnemonic).Generate(password)).digest(),
      [44 + (1 << 31), 5132 + (1 << 31), 0 + (1 << 31), 1, index]
    )
  ).toPoint().serialize()

def getAddress(
  mnemonic: str,
  password: str,
  index: int
) -> str:
  return bech32_encode("mr", convertbits(bytes([0]) + getPublicKey(mnemonic, password, index), 8, 5), Encoding.BECH32M)

def decodeAddress(
  address: str
) -> bytes:
  decoded: Union[Tuple[None, None, None], Tuple[str, List[int], Encoding]] = bech32_decode(address)
  if decoded[1] is None:
    raise TestError("Decoding an invalid address.")
  if decoded[2] != Encoding.BECH32M:
    raise TestError("Bech32 instead of Bech32m.")
  res: List[int] = convertbits(decoded[1], 5, 8)
  if res[0] != 0:
    raise TestError("Decoding an address which isn't a Public Key.")
  return bytes(res[1:33])
