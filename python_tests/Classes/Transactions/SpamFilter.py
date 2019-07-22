#Types.
from typing import Tuple

#Argon2 lib.
import argon2

class SpamFilter:
    def __init__(
        self,
        difficulty: bytes
    ) -> None:
        self.difficulty: bytes = difficulty

    @staticmethod
    def run(
        data: bytes,
        nonce: int
    ) -> bytes:
        result: bytes = argon2.low_level.hash_secret_raw(
            data,
            nonce.to_bytes(8, byteorder = "big"),
            1,
            8,
            1,
            48,
            argon2.low_level.Type.D
        )
        return result

    def beat(
        self,
        hash: bytes
    ) -> Tuple[bytes, int]:
        result: int = -1
        argon: bytes = b""
        while int.from_bytes(argon, byteorder = "big") < int.from_bytes(self.difficulty, byteorder = "big"):
            result += 1
            argon = self.run(hash, result)
        return (argon, result)
