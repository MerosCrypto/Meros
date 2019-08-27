from enum import Enum

class Type(Enum):
    D = ...

def hash_secret_raw(
    data: bytes,
    salt: bytes,
    time: int,
    memory: int,
    parallelism: int,
    length: int,
    type: Type
) -> bytes:
    ...
