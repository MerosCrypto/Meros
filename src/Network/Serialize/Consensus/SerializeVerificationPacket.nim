import algorithm

import ../../../lib/[Errors, Hash]
import ../../../Wallet/MinerWallet

import ../../../Database/Consensus/Elements/objects/VerificationPacketObj

import ../SerializeCommon
import SerializeElement
export SerializeElement

#Serialize a VerificationPacket.
method serialize*(
  packet: VerificationPacket
): string {.forceCheck: [].} =
  result = packet.holders.len.toBinary(NICKNAME_LEN)
  for holder in packet.holders.sorted():
    result &= holder.toBinary(NICKNAME_LEN)
  result &= packet.hash.serialize()

#Serialize a VerificationPacket for inclusion in a BlockHeader's contents Merkle.
method serializeContents*(
  packet: VerificationPacket
): string {.inline, forceCheck: [].} =
  char(VERIFICATION_PACKET_PREFIX) &
  packet.serialize()
