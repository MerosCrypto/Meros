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
    inputs: varargs[FundedInput],
    output: EdPublicKey
): Claim {.forceCheck: [
    ValueError
].} =
    #Verify the inputs length.
    if inputs.len < 1 or 255 < inputs.len:
        raise newException(ValueError, "Claim has too little or too many inputs.")

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
        claim.signature = signature
        claim.hash = Blake384(claim.serializeHash())
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when signing a Claim: " & e.msg)

#Verify a Claim.
proc verify*(
    claim: Claim,
    claimer: BLSPublicKey
): bool {.forceCheck: [].} =
    #Create a seq of AggregationInfos.
    var agInfos: seq[BLSAggregationInfo] = newSeq[BLSAggregationInfo](claim.inputs.len)

    try:
        #Create each AggregationInfo.
        for i in 0 ..< claim.inputs.len:
                agInfos[i] = newBLSAggregationInfo(
                    claimer,
                    (
                        "\1" &
                        claim.inputs[i].hash.toString() &
                        char(cast[FundedInput](claim.inputs[i]).nonce) &
                        cast[SendOutput](claim.outputs[0]).key.toString()
                    )
                )

        #Verify the signature.
        claim.signature.setAggregationInfo(agInfos.aggregate())
        result = claim.signature.verify()
    except BLSError:
        return false
