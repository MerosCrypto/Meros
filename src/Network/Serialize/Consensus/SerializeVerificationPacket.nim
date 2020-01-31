#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#VerificationPacket object.
import ../../../Database/Consensus/Elements/objects/VerificationPacketObj

#Common serialization functions.
import ../SerializeCommon

#SerializeElement method.
import SerializeElement
export SerializeElement

#Algorithm standard lib.
import algorithm

#Serialize a VerificationPacket.
method serialize*(
    packet: VerificationPacket
): string {.forceCheck: [].} =
    result = packet.holders.len.toBinary(NICKNAME_LEN)
    for holder in packet.holders.sorted():
        result &= holder.toBinary(NICKNAME_LEN)
    result &= packet.hash.toString()

#Serialize a VerificationPacket (as a MeritRemovalVerificationPacket) for a MeritRemoval.
#The holders are included, as neccessary, to handle the signature, which makes this a misnomer.
#That said, this isn't a misnomer for every other Element, and this method must exist for every Element (by name).
method serializeWithoutHolder*(
    packet: MeritRemovalVerificationPacket
): string {.forceCheck: [].} =
    result = char(VERIFICATION_PACKET_PREFIX) & packet.holders.len.toBinary(NICKNAME_LEN)
    for holder in packet.holders:
        result &= holder.serialize()
    result &= packet.hash.toString()

#Used to generate MeritRemoval AggregationInfos.
#We generally call to serializeWithoutHolder for this but VerificationPackets are an edge case.
proc serializeAsVerificationWithoutHolder*(
    packet: MeritRemovalVerificationPacket
): string {.inline, forceCheck: [].} =
    char(VERIFICATION_PREFIX) & packet.hash.toString()

#Serialize a VerificationPacket for inclusion in a BlockHeader's contents Merkle.
method serializeContents*(
    packet: VerificationPacket
): string {.inline, forceCheck: [].} =
    char(VERIFICATION_PACKET_PREFIX) &
    packet.serialize()
