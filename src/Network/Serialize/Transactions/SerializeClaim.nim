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

#SerializeTransaction method.
import SerializeTransaction
export SerializeTransaction

#Serialization functions.
method serializeHash*(
    claim: Claim
): string {.forceCheck: [].} =
    result = "\1" & claim.signature.toString()

method serialize*(
    claim: Claim
): string {.inline, forceCheck: [].} =
    #Serialize the inputs.
    result = $char(claim.inputs.len)
    for input in claim.inputs:
        result &= input.hash.toString()

    #Serialize the output and signature.
    result &=
        cast[SendOutput](claim.outputs[0]).key.toString() &
        claim.signature.toString()
