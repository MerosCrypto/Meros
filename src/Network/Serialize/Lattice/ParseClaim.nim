#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Wallet lib.
import ../../../Wallet/Wallet

#Entry and Claim objects.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/Claim

#Serialize common functions.
import ../SerializeCommon

#Parse a Claim.
proc parseClaim*(
    claimStr: string
): Claim {.forceCheck: [
    ValueError,
    BLSError,
    EdPublicKeyError
].} =
    #Public Key | Nonce | Mint Nonce | BLS Signature | Signature
    var claimSeq: seq[string] = claimStr.deserialize(
        PUBLIC_KEY_LEN,
        INT_LEN,
        INT_LEN,
        BLS_SIGNATURE_LEN,
        SIGNATURE_LEN
    )

    #Create the Claim.
    result = newClaim(
        claimSeq[2].fromBinary(),
        claimSeq[1].fromBinary()
    )

    try:
        #Set the sender.
        try:
            result.sender = newAddress(claimSeq[0])
        except EdPublicKeyError as e:
            fcRaise e

        #Set the BLS signature.
        try:
            result.bls = newBLSSignature(claimSeq[3])
        except BLSError as e:
            fcRaise e

        #Set the hash.
        result.hash = Blake384("claim" & claimSeq.reserialize(1, 3))
        #Set the signature.
        result.signature = newEdSignature(claimSeq[4])
        result.signed = true
    except ValueError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Claim: " & e.msg)
