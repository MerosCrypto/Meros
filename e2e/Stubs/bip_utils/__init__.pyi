from enum import Enum

class Bip39WordsNum(Enum):
  WORDS_NUM_12: int = ...
  WORDS_NUM_24: int = ...

class Bip39MnemonicGenerator:
  @staticmethod
  def FromWordsNumber(
    num: Bip39WordsNum
  ) -> str:
    ...

class Bip39MnemonicValidator:
  def __init__(
    self,
    mnemonic: str
  ) -> None:
    ...

  def Validate(
    self
  ) -> bool:
    ...

class Bip39SeedGenerator:
  def __init__(
    self,
    mnemonic: str
  ) -> None:
    ...

  def Generate(
    self,
    password: str
  ) -> bytes:
    ...
