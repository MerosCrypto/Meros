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

#Serialize a VerificationPacket.
method serialize*(
    packet: VerificationPacket
): string {.forceCheck: [].} =
    result = packet.holders.len.toBinary().pad(NICKNAME_LEN)
    for holder in packet.holders:
        result &= holder.toBinary().pad(NICKNAME_LEN)
    result &= packet.hash.toString()

#Serialize a VerificationPacket for a MeritRemoval.
#The holders are included, as neccessary, to handle the signature, which makes this a misnomer.
#That said, this isn't a misnomer for every other Element, and this method must exist for every Element (by name).
method serializeWithoutHolder*(
    packet: VerificationPacket
): string {.forceCheck: [].} =
    result =
        char(VERIFICATION_PACKET_PREFIX) &
        packet.serialize()

#Serialize a Signed VerificationPacket.
method signedSerialize*(
    packet: SignedVerificationPacket
): string {.forceCheck: [].} =
    result =
        packet.serialize() &
        packet.signature.toString()
