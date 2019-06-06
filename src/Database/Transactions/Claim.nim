#Errors lib.
import ../../lib/Errors

#Transaction lib.
import Transaction

#Claim object.
import objects/ClaimObj
export ClaimObj

#Create a new Claim.
func newClaim*(
    inputs: seq[Input],
    output: ClaimOutput
): Claim {.forceCheck: [
    ValueError
].} =
    #Verify the inputs length.
    if inputs.len == 0:
        raise newException(ValueError, "Claim doesn't have any inputs.")

    #Create the result.
    result = newClaimObj(
        output,
        amount
    )

    #Hash it.
    discard result.hash

#Sign a Claim.
proc sign*(
    wallet: MinerWallet,
    claim: Claim
) {.forceCheck: [].} =
    var signatures: seq[BLSSignature] = newSeq[BLSSignature](claim.inputs.len)
    for i in 0 ..< signatures.len:
        signatures[i] = wallet.sign("\1" + claim.inputs[i].hash.toString() + claim.outputs[0].key.toString())
    claim.bls = signatures.aggregate()
