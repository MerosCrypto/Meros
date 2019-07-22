class SigningKey:
    def __init__(
        self,
        seed: bytes
    ) -> None:
        ...

    def sign(
        self,
        msg: bytes
    ) -> bytes:
        ...

    def get_verifying_key(
        self
    ) -> VerifyingKey:
        ...

class VerifyingKey:
    def to_bytes(
        self
    ) -> bytes:
        ...
