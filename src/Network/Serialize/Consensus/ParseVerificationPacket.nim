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
    if packet.len < BYTE_LEN:
        raise newException(ValueError, "parseVerificationPacket not handed enough data to get the amount of verifiers.")
    verifiers = packet[0 ..< BYTE_LEN].fromBinary()
    if packet.len != BYTE_LEN + (verifiers * NICKNAME_LEN) + HASH_LEN:
        raise newException(ValueError, "parseVerificationPacket not handed enough data to get the verifiers and hash.")

    #Create the VerificationPacket.
    try:
        result = newVerificationPacketObj(
            packet[packet.len - HASH_LEN ..< packet.len].toHash(384)
        )
        for v in 0 ..< verifiers:
            result.holders.add(
                uint16(packet[BYTE_LEN + (NICKNAME_LEN * v) ..< BYTE_LEN + (NICKNAME_LEN * (v + 1))].fromBinary())
            )
    except ValueError as e:
        raise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a VerificationPacket: " & e.msg)

#Parse a MeritRemoval's VerificationPacket.
proc parseMeritRemovalVerificationPacket*(
    packet: string
): MeritRemovalVerificationPacket {.forceCheck: [
    ValueError
].} =
    #Amount of Verifiers | Verifiers | Transaction Hash

    #Verify the data length.
    var verifiers: int
    if packet.len < BYTE_LEN:
        raise newException(ValueError, "parseMeritRemovalVerificationPacket not handed enough data to get the amount of verifiers.")
    verifiers = packet[0].fromBinary()
    if packet.len != BYTE_LEN + (verifiers * BLS_PUBLIC_KEY_LEN) + HASH_LEN:
        raise newException(ValueError, "parseMeritRemovalVerificationPacket not handed enough data to get the verifiers and hash.")

    #Create the MeritRemovalVerificationPacket.
    try:
        result = newMeritRemovalVerificationPacketObj(
            packet[packet.len - HASH_LEN ..< packet.len].toHash(384)
        )
        for v in 0 ..< verifiers:
            result.holders.add(
                newBLSPublicKey(packet[BYTE_LEN + (BLS_PUBLIC_KEY_LEN * v) ..< BYTE_LEN + (BLS_PUBLIC_KEY_LEN * (v + 1))])
            )
    except ValueError as e:
        raise e
    except BLSError:
        raise newException(ValueError, "Invalid Public Key.")
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a VerificationPacket: " & e.msg)
