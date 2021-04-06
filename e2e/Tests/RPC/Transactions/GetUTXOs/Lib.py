from typing import Dict, Any

from e2e.Libs.BLS import PrivateKey
from e2e.Libs.RandomX import RandomX

from e2e.Classes.Consensus.Verification import SignedVerification

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def verify(
  rpc: RPC,
  txHash: bytes,
  nick: int = 0,
  mr: bool = False
) -> None:
  sv: SignedVerification = SignedVerification(txHash)
  sv.sign(nick, PrivateKey(nick))
  temp: bytes = rpc.meros.signedElement(sv)
  if mr:
    if MessageType(rpc.meros.live.recv()[0]) != MessageType.SignedMeritRemoval:
      raise TestError("Meros didn't create a MeritRemoval.")
  elif temp != rpc.meros.live.recv():
    raise TestError("Meros didn't broadcast back a Verification.")

#This really should've been vectored out.
def mineBlock(
  rpc: RPC,
  nick: int = 0
) -> None:
  privKey: PrivateKey = PrivateKey(nick)
  template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", {"miner": privKey.toPublicKey().serialize().hex()})
  header: bytes = bytes.fromhex(template["header"])[:-4]
  header += (rpc.call("merit", "getBlock", {"block": rpc.call("merit", "getHeight") - 1})["header"]["time"] + 1200).to_bytes(4, "little")

  proof: int = -1
  tempHash: bytes = bytes()
  signature: bytes = bytes()
  while (
    (proof == -1) or
    ((int.from_bytes(tempHash, "little") * template["difficulty"]) > int.from_bytes(bytes.fromhex("FF" * 32), "little"))
  ):
    proof += 1
    tempHash = RandomX(header + proof.to_bytes(4, "little"))
    signature = privKey.sign(tempHash).serialize()
    tempHash = RandomX(tempHash + signature)

  rpc.call("merit", "publishBlock", {"id": template["id"], "header": header.hex() + proof.to_bytes(4, "little").hex() + signature.hex()})
  if rpc.meros.live.recv() != (MessageType.BlockHeader.toByte() + header + proof.to_bytes(4, "little") + signature):
    raise TestError("Meros didn't broadcast back the BlockHeader.")
