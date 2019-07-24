#Types.
from typing import List

class PrivateKey:
    @staticmethod
    def from_seed(
        seed: bytes
    ) -> PrivateKey:
        ...

    def sign(
        self,
        msg: bytes
    ) -> Signature:
        ...

    def get_public_key(
        self
    ) -> PublicKey:
        ...

class PublicKey:
    @staticmethod
    def from_bytes(
        pubKey: bytes
    ) -> PublicKey:
        ...

    def serialize(
        self
    ) -> bytes:
        ...

class Signature:
    @staticmethod
    def aggregate(
        sigs: List[Signature]
    ) -> Signature:
        ...

    def serialize(
        self
    ) -> bytes:
        ...
