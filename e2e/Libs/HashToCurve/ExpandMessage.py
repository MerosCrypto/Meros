from typing import Callable, List, Any

#https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-09#section-5.4.1
def expandMessageXMD(
  #pylint: disable=invalid-name
  H: Callable[[bytes], Any],
  dst: str,
  msg: bytes,
  outLen: int
) -> bytes:
  h: Any = H("".encode("utf-8"))
  bInBytes: int = h.digest_size
  rInBytes: int = h.block_size

  #Steps 1-2.
  ell: int = ((outLen + bInBytes) - 1) // bInBytes
  if ell > 255:
    raise Exception("Invalid XMD output length set given the hash function.")

  #Steps 3-4.
  if len(dst) > 255:
    raise Exception("Invalid DST.")
  dstPrime: bytes = dst.encode("utf-8") + len(dst).to_bytes(1, "big")
  zPad: bytes = bytes([0] * rInBytes)
  if outLen > 65535:
    raise Exception("Invalid XMD output length.")

  #Steps 5-6.
  msgPrime: bytes = zPad + msg + outLen.to_bytes(2, "big") + bytes([0]) + dstPrime

  #Steps 7-8.
  #b0
  b: List[bytes] = [H(msgPrime).digest()]
  #b1
  b.append(H(b[0] + bytes([1]) + dstPrime).digest())

  #Steps 9-10.
  for i in range(2, ell + 1):
    b.append(
      H(
        bytes([b[0][i] ^ b[-1][i] for i in range(len(b[0]))]) +
        i.to_bytes(1, "big") +
        dstPrime
      ).digest()
    )

  #Steps 11-12.
  return (b"".join(b[1:]))[0 : outLen]
