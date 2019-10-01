#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#VerificationPacket object.
import ../../../Database/Consensus/Elements/objects/VerificationPacketObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Parse a VerificationPacket.
proc parseVerificationPacket*(
    packet: string
): VerificationPacket {.forceCheck: [
    ValueError
].} =
    #Amount of Verifiers | Verifiers' Nicknames | Transaction Hash

    #Verify the data length.
    var verifiers: int
    if packet.len < NICKNAME_LEN:
        raise newException(ValueError, "parseVerificationPacket not handed enough data to get the amount of verifiers.")
    verifiers = packet[0 ..< NICKNAME_LEN].fromBinary()
    if packet.len != ((verifiers + 1) * NICKNAME_LEN) + HASH_LEN:
        raise newException(ValueError, "parseVerificationPacket not handed enough data to get the verifiers and hash.")

    #Create the VerificationPacket.
    try:
        result = newVerificationPacketObj(
            packet[packet.len - HASH_LEN ..< packet.len].toHash(384)
        )
        for v in 0 ..< verifiers:
            result.holders.add(
                uint16(packet[NICKNAME_LEN * (v + 1) ..< NICKNAME_LEN * (v + 2)].fromBinary())
            )
    except ValueError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a VerificationPacket: " & e.msg)

#Parse a Signed VerificationPacket.
proc parseSignedVerificationPacket*(
    packet: string
): SignedVerificationPacket {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Amount of Verifiers | Verifiers' Nicknames | Transaction Hash | BLS Signature

    #Verify the data length.
    var verifiers: int
    if packet.len < NICKNAME_LEN:
        raise newException(ValueError, "parseVerificationPacket not handed enough data to get the amount of verifiers.")
    verifiers = packet[0 ..< NICKNAME_LEN].fromBinary()
    if packet.len != ((verifiers + 1) * NICKNAME_LEN) + HASH_LEN + BLS_SIGNATURE_LEN:
        raise newException(ValueError, "parseVerificationPacket not handed enough data to get the verifiers, hash, and signature.")

    #Create the VerificationPacket.
    try:
        result = newSignedVerificationPacketObj(
            packet[packet.len - (BLS_SIGNATURE_LEN + HASH_LEN) ..< packet.len - BLS_SIGNATURE_LEN].toHash(384)
        )
        for v in 0 ..< verifiers:
            result.holders.add(
                uint16(packet[NICKNAME_LEN * (v + 1) ..< NICKNAME_LEN * (v + 2)].fromBinary())
            )
        result.signature = newBLSSignature(packet[packet.len - BLS_SIGNATURE_LEN ..< packet.len])
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a SignedVerificationPacket: " & e.msg)
