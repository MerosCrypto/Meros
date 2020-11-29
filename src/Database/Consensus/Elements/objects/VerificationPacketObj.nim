import algorithm

import ../../../../lib/[Errors, Hash]
import ../../../../Wallet/MinerWallet

import ElementObj

type
  VerificationPacket* = ref object of RootObj
    holders*: seq[uint16]
    hash*: Hash[256]

  SignedVerificationPacket* = ref object of VerificationPacket
    signature*: BLSSignature

func newVerificationPacketObj*(
  hash: Hash[256]
): VerificationPacket {.inline, forceCheck: [].} =
  VerificationPacket(
    hash: hash
  )

func newSignedVerificationPacketObj*(
  hash: Hash[256]
): SignedVerificationPacket {.inline, forceCheck: [].} =
  SignedVerificationPacket(
    hash: hash
  )

proc `==`*(
  vp1: VerificationPacket,
  vp2: VerificationPacket
): bool {.inline, forceCheck: [].} =
  (
    (sorted(vp1.holders) == sorted(vp2.holders)) and
    (vp1.hash == vp2.hash) and
    ((vp1 of SignedVerificationPacket) == (vp2 of SignedVerificationPacket)) and
    (
      (vp1 of SignedVerificationPacket) and
      (cast[SignedVerificationPacket](vp1).signature == cast[SignedVerificationPacket](vp2).signature)
    )
  )

proc `!=`*(
  vp1: VerificationPacket,
  vp2: VerificationPacket
): bool {.inline, forceCheck: [].} =
  not (vp1 == vp2)
