from typing import Tuple

import argon2

class SpamFilter:
  def __init__(
    self,
    difficulty: int
  ) -> None:
    self.difficulty: int = difficulty

  @staticmethod
  def run(
    data: bytes,
    nonce: int
  ) -> bytes:
    result: bytes = argon2.low_level.hash_secret_raw(
      data,
      nonce.to_bytes(8, "little"),
      1,
      8,
      1,
      32,
      argon2.low_level.Type.D
    )
    return result

  def beat(
    self,
    txHash: bytes,
    factor: int
  ) -> Tuple[bytes, int]:
    result: int = 0
    argon: bytes = self.run(txHash, result)
    while (
      int.from_bytes(argon, "little") *
      (self.difficulty * factor)
    ) > int.from_bytes(bytes.fromhex("FF" * 32), "little"):
      result += 1
      argon = self.run(txHash, result)
    return (argon, result)
