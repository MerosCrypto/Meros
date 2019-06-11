#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet libs.
import ../../../Wallet/Wallet
import ../../../Wallet/MinerWallet

#Claim object.
import ../../../Database/Transactions/objects/ClaimObj

#Common serialization functions.
import ../SerializeCommon

#Parse function.
proc parseClaim*(
    claimStr: string
): Claim {.forceCheck: [
    ValueError,
    EdPublicKeyError,
    BLSError
].} =
    #Verify the input length.
    if claimStr.len < BYTE_LEN:
        raise newException(ValueError, "parseClaim not handed enough data to get the amount of inputs.")

    #Inputs Length | Input Hashes | Output Ed25519 Key | BLS Signatture
    var claimSeq: seq[string] = claimStr.deserialize(
        BYTE_LEN,
        claimStr[0].fromBinary() * HASH_LEN,
        ED_PUBLIC_KEY_LEN,
        BLS_SIGNATURE_LEN
    )

    #Convert the inputs.
    var inputs: seq[Input] = newSeq[Input](claimSeq[1].len div 48)
    if inputs.len == 0:
        raise newException(ValueError, "parseClaim handed a Claim with no inputs.")
    for i in countup(0, claimSeq[1].len - 1, 48):
        try:
            inputs[i div 48] = newInput(claimSeq[1][i ..< i + 48].toHash(384))
        except ValueError as e:
            fcRaise e

    #Create the Claim.
    try:
        result = newClaimObj(
            inputs,
            newEdPublicKey(claimSeq[2])
        )
    except EdPublicKeyError as e:
        fcRaise e

    #Set the signature and hash it.
    try:
        result.signature = newBLSSignature(claimSeq[3])
        result.hash = Blake384("\1" & claimSeq[3])
    except BLSError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Claim: " & e.msg)
