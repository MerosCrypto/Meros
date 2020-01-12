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
    if packet.len != NICKNAME_LEN + (verifiers * NICKNAME_LEN) + HASH_LEN:
        raise newException(ValueError, "parseVerificationPacket not handed enough data to get the verifiers and hash.")

    #Create the VerificationPacket.
    try:
        result = newVerificationPacketObj(
            packet[packet.len - HASH_LEN ..< packet.len].toHash(256)
        )
        for v in 0 ..< verifiers:
            result.holders.add(
                uint16(packet[NICKNAME_LEN + (NICKNAME_LEN * v) ..< NICKNAME_LEN + (NICKNAME_LEN * (v + 1))].fromBinary())
            )
    except ValueError as e:
        raise e

#Parse a MeritRemoval's VerificationPacket.
proc parseMeritRemovalVerificationPacket*(
    packet: string
): MeritRemovalVerificationPacket {.forceCheck: [
    ValueError
].} =
    #Amount of Verifiers | Verifiers | Transaction Hash

    #Verify the data length.
    var verifiers: int
    if packet.len < NICKNAME_LEN:
        raise newException(ValueError, "parseMeritRemovalVerificationPacket not handed enough data to get the amount of verifiers.")
    verifiers = packet[0 ..< NICKNAME_LEN].fromBinary()
    if packet.len != NICKNAME_LEN + (verifiers * BLS_PUBLIC_KEY_LEN) + HASH_LEN:
        raise newException(ValueError, "parseMeritRemovalVerificationPacket not handed enough data to get the verifiers and hash.")

    #Create the MeritRemoval VerificationPacket.
    try:
        result = newMeritRemovalVerificationPacketObj(
            packet[packet.len - HASH_LEN ..< packet.len].toHash(256)
        )
        for v in 0 ..< verifiers:
            result.holders.add(
                newBLSPublicKey(packet[NICKNAME_LEN + (BLS_PUBLIC_KEY_LEN * v) ..< NICKNAME_LEN + (BLS_PUBLIC_KEY_LEN * (v + 1))])
            )
    except ValueError as e:
        raise e
    except BLSError:
        raise newException(ValueError, "Invalid Public Key.")
