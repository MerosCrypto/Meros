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

#Serialize a VerificationPacket (as a MeritRemovalVerificationPacket) for a MeritRemoval.
#The holders are included, as neccessary, to handle the signature, which makes this a misnomer.
#That said, this isn't a misnomer for every other Element, and this method must exist for every Element (by name).
method serializeWithoutHolder*(
  packet: MeritRemovalVerificationPacket
): string {.forceCheck: [].} =
  result = char(VERIFICATION_PACKET_PREFIX) & packet.holders.len.toBinary(NICKNAME_LEN)
  for holder in packet.holders:
    result &= holder.serialize()
  result &= packet.hash.serialize()

#Used to generate MeritRemoval AggregationInfos.
#We generally call to serializeWithoutHolder for this but VerificationPackets are an edge case.
proc serializeAsVerificationWithoutHolder*(
  packet: MeritRemovalVerificationPacket
): string {.inline, forceCheck: [].} =
  char(VERIFICATION_PREFIX) & packet.hash.serialize()

#Serialize a VerificationPacket for inclusion in a BlockHeader's contents Merkle.
method serializeContents*(
  packet: VerificationPacket
): string {.inline, forceCheck: [].} =
  char(VERIFICATION_PACKET_PREFIX) &
  packet.serialize()
