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

class AggregationInfo:
    @staticmethod
    def from_msg(
        pubKey: PublicKey,
        msg: bytes
    ) -> AggregationInfo:
        ...

class Signature:
    @staticmethod
    def from_bytes(
        pubKey: bytes
    ) -> Signature:
        ...

    @staticmethod
    def aggregate(
        sigs: List[Signature]
    ) -> Signature:
        ...

    def set_aggregation_info(
        self,
        agInfo: AggregationInfo
    ) -> None:
        ...

    def serialize(
        self
    ) -> bytes:
        ...
