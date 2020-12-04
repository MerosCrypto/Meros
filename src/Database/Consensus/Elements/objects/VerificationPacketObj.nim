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
