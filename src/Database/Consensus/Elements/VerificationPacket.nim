import ../../../lib/Errors
import ../../../Wallet/MinerWallet

import Verification

import objects/VerificationPacketObj
export VerificationPacketObj

#Convert a VerificationPacket to a MeritRemovalVerificationPacket.
#VerificationPackets use the holder's nickname.
#MRVPs use the holder's keys. That's why this requires the lookup
proc toMeritRemovalVerificationPacket*(
  packet: VerificationPacket,
  lookup: seq[BLSPublicKey]
): MeritRemovalVerificationPacket {.forceCheck: [].} =
  result = newMeritRemovalVerificationPacketObj(packet.hash)
  for holder in packet.holders:
    result.holders.add(lookup[holder])

proc add*(
  packet: VerificationPacket,
  verif: Verification
) {.forceCheck: [].} =
  packet.holders.add(verif.holder)

proc add*(
  packet: SignedVerificationPacket,
  verif: SignedVerification
) {.forceCheck: [].} =
  packet.holders.add(verif.holder)
  if packet.signature.isInf:
    packet.signature = verif.signature
  else:
    packet.signature = @[
      packet.signature,
      verif.signature
    ].aggregate()

#Error if the add function is called when one arg is signed but the other is not.
proc add*(
  packet: VerificationPacket,
  verif: SignedVerification
) {.error: "Adding a SignedVerification to a VerificationPacket".}

proc add*(
  packet: SignedVerificationPacket,
  verif: Verification
) {.error: "Adding a Verification to a SignedVerificationPacket".}
