#Argon2 lib.
import argon2

#BlockHeader class.
class BlockHeader:
    #Constructor.
    def __init__(
        self,
        nonce: int,
        last: bytes,
        time: int,
        aggregate: bytes = bytes(96),
        miners: bytes = bytes(48),
        proof: int = 0
    ) -> None:
        self.nonce = nonce
        self.last = last
        self.time = time
        self.aggregate = aggregate
        self.miners = miners
        self.proof = proof

        self.hash = bytes(48)

    #Set aggregate.
    def setAggregate(
        self,
        aggregate: bytes
    ) -> None:
        self.aggregate = aggregate

    #Set miners.
    def setMiners(
        self,
        miners: bytes
     )-> None:
        self.miners = miners

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return (
            self.nonce.to_bytes(4, byteorder="big") +
            self.last +
            self.aggregate +
            self.miners +
            self.time.to_bytes(4, byteorder="big") +
            self.proof.to_bytes(4, byteorder="big")
        )

    #Hash.
    def rehash(
        self
    ) -> None:
        self.hash = argon2.low_level.hash_secret_raw(
            self.serialize()[0 : 200],
            self.serialize()[200 : 204].rjust(8, b'\0'),
            1,
            131072,
            1,
            48,
            argon2.low_level.Type.D
        )
