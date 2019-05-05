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
    BLSError,
    EdPublicKeyError
].} =
    var
        #Public Key | Nonce | Mint Nonce | BLS Signature | Signature
        claimSeq: seq[string] = claimStr.deserialize(
            PUBLIC_KEY_LEN,
            INT_LEN,
            INT_LEN,
            BLS_SIGNATURE_LEN,
            SIGNATURE_LEN
        )
        #Get the sender's Public Key.
        sender: EdPublicKey
        #Get the nonce.
        nonce: int = claimSeq[1].fromBinary()
        #Get the mint nonce.
        mintNonce: int = claimSeq[2].fromBinary()
        #Get the BLS signature.
        bls: BLSSignature
        #Get the signature.
        signature: EdSignature = newEdSignature(claimSeq[4])

    try:
        sender = newEdPublicKey(claimSeq[0])
    except EdPublicKeyError as e:
        fcRaise e

    try:
        bls = newBLSSignature(claimSeq[3])
    except BLSError as e:
        fcRaise e

    #Create the Claim.
    result = newClaim(
        mintNonce,
        nonce
    )

    try:
        #Set the sender.
        result.sender = newAddress(sender)
        #Set the BLS signature.
        result.bls = bls

        #Set the hash.
        result.hash = Blake384("claim" & claimSeq.reserialize(1, 3))
        #Set the signature.
        result.signature = signature
        result.signed = true
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Claim: " & e.msg)
