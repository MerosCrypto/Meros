import ../../../../lib/[Errors, Hash]
import ../../../../Wallet/MinerWallet

import ElementObj

type
  VerificationPacket* = ref object of Element
    holders*: seq[uint16]
    hash*: Hash[256]

  MeritRemovalVerificationPacket* = ref object of Element
    holders*: seq[BLSPublicKey]
    hash*: Hash[256]

  SignedVerificationPacket* = ref object of VerificationPacket
    signature*: BLSSignature

func newVerificationPacketObj*(
  hash: Hash[256]
): VerificationPacket {.inline, forceCheck: [].} =
  VerificationPacket(
    hash: hash
  )

func newMeritRemovalVerificationPacketObj*(
  hash: Hash[256]
): MeritRemovalVerificationPacket {.inline, forceCheck: [].} =
  MeritRemovalVerificationPacket(
    hash: hash
  )

func newSignedVerificationPacketObj*(
  hash: Hash[256]
): SignedVerificationPacket {.inline, forceCheck: [].} =
  SignedVerificationPacket(
    hash: hash
  )
