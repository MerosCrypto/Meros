#Errors lib.
import ../../../lib/Errors

#Transaction objects.
import ../../../Database/Transactions/objects/MintObj
import ../../../Database/Transactions/objects/ClaimObj
import ../../../Database/Transactions/objects/SendObj

#Serialization libs.
import SerializeMint
import SerializeClaim
import SerializeSend

#Serialize the TransactionObj.
proc serialize*(
    tx: Transaction
): string {.forceCheck: [].} =
    case tx.descendant:
        of TransactionType.Mint:
            result = cast[Mint](tx).serialize()
        of TransactionType.Claim:
            result = cast[Claim](tx).serialize()
        of TransactionType.Send:
            result = cast[Send](tx).serialize()
