#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet
import ../../Wallet/MinerWallet

#Claim object.
import objects/ClaimObj
export ClaimObj

#Mint object.
import objects/MintObj

#Create a new Claim.
proc newClaim*(
    mints: seq[Mint],
    output: EdPublicKey
): Claim {.forceCheck: [
    ValueError
].} =
    #Verify the mints length.
    if mints.len == 0:
        raise newException(ValueError, "Claim doesn't have any mints.")

    #Create the result.
    result = newClaimObj(
        mints,
        output
    )

    #Hash it.
    try:
        discard
        #result.hash = Blake384(result.serializeHash())
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Claim: " & e.msg)

#Sign a Claim.
proc sign*(
    wallet: MinerWallet,
    claim: Claim
) {.forceCheck: [
    BLSError
].} =
    var signatures: seq[BLSSignature] = newSeq[BLSSignature](claim.inputs.len)
    try:
        for i in 0 ..< signatures.len:
            signatures[i] = wallet.sign("\1" & claim.inputs[i].hash.toString() & cast[SendOutput](claim.outputs[0]).key.toString())
        try:
            claim.bls = signatures.aggregate()
        except FinalAttributeError as e:
            doAssert(false, "Set a final attribute twice when signing a Claim: " & e.msg)
    except BLSError as e:
        fcRaise e
