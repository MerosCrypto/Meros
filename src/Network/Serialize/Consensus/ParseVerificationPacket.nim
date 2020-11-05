import ../../../lib/[Errors, Hash]
import ../../../Wallet/MinerWallet

import ../../../Database/Consensus/Elements/objects/VerificationPacketObj

import ../SerializeCommon

proc parseVerificationPacket*(
  packet: string
): VerificationPacket {.forceCheck: [
  ValueError
].} =
  #Amount of Verifiers | Verifiers' Nicknames | Transaction Hash

  #Verify the data length.
  if packet.len < NICKNAME_LEN:
    raise newLoggedException(ValueError, "parseVerificationPacket not handed enough data to get the amount of verifiers.")
  var verifiers: int = packet[0 ..< NICKNAME_LEN].fromBinary()
  if verifiers == 0:
    raise newLoggedException(ValueError, "Verification Packet has no Merit Holders.")
  if packet.len != NICKNAME_LEN + (verifiers * NICKNAME_LEN) + HASH_LEN:
    raise newLoggedException(ValueError, "parseVerificationPacket not handed enough data to get the verifiers and hash.")

  result = newVerificationPacketObj(
    packet[packet.len - HASH_LEN ..< packet.len].toHash[:256]()
  )
  for v in 0 ..< verifiers:
    result.holders.add(
      uint16(packet[NICKNAME_LEN + (NICKNAME_LEN * v) ..< NICKNAME_LEN + (NICKNAME_LEN * (v + 1))].fromBinary())
    )
