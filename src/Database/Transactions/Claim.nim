#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet
import ../../Wallet/MinerWallet

#Mint object.
import objects/MintObj

#Claim object.
import objects/ClaimObj
export ClaimObj

#Serialization lib.
import ../../Network/Serialize/Transactions/SerializeClaim

#Create a new Claim.
proc newClaim*(
    mints: seq[Mint],
    output: EdPublicKey
): Claim {.forceCheck: [
    ValueError
].} =
    #Verify the mints length.
    if mints.len < 1 or 255 < mints.len:
        raise newException(ValueError, "Claim has too little or too many Mints.")

    #Convert the inputs.
    var inputs: seq[Input] = newSeq[Input](mints.len)
    for i in 0 ..< mints.len:
        inputs[i] = newInput(mints[i].hash)

    #Create the result.
    result = newClaimObj(
        inputs,
        output
    )

#Sign a Claim.
proc sign*(
    wallet: MinerWallet,
    claim: Claim
) {.forceCheck: [
    BLSError
].} =
    #Create a seq of signatures.
    var
        #Final signature.
        signature: BLSSignature
        #Signature of each input.
        signatures: seq[BLSSignature] = newSeq[BLSSignature](claim.inputs.len)

    try:
        #Sign every input.
        for i in 0 ..< signatures.len:
            signatures[i] = wallet.sign("\1" & claim.inputs[i].hash.toString() & cast[SendOutput](claim.outputs[0]).key.toString())

        #Aggregate the input signatures.
        signature = signatures.aggregate()
    except BLSError as e:
        fcRaise e

    #Set the signature and hash the Claim.
    try:
        claim.bls = signature
        claim.hash = Blake384(claim.serializeHash())
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Claim: " & e.msg)
