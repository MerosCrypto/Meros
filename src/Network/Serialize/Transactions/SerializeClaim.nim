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

#Serialization functions.
proc serializeHash*(
    claim: Claim
): string {.forceCheck: [].} =
    result = "\1" & claim.signature.toString()

proc serialize*(
    claim: Claim
): string {.inline, forceCheck: [].} =
    #Serialize the inputs.
    result = claim.inputs.len.toBinary().pad(BYTE_LEN)
    for input in claim.inputs:
        result &= input.hash.toString()

    #Serialize the output and signature.
    result &=
        cast[SendOutput](claim.outputs[0]).key.toString() &
        claim.signature.toString()
