#Errors lib.
import ../../../../../lib/Errors

#Transaction objects.
import ../../../../../Database/Transactions/objects/MintObj
import ../../../../../Database/Transactions/objects/ClaimObj
import ../../../../../Database/Transactions/objects/SendObj

#Serialization libs.
import SerializeMint
import ../../../../../Network/Serialize/Transactions/SerializeClaim
import ../../../../../Network/Serialize/Transactions/SerializeSend

#Serialize the TransactionObj.
proc serialize*(
    tx: Transaction
): string {.forceCheck: [].} =
    case tx.descendant:
        of TransactionType.Mint:
            result = char(TransactionType.Mint) & cast[Mint](tx).serialize()
        of TransactionType.Claim:
            result = char(TransactionType.Claim) & cast[Claim](tx).serialize()
        of TransactionType.Send:
            result = char(TransactionType.Send) & cast[Send](tx).serialize()
