#Errors lib.
import ../../../../../lib/Errors

#Transaction objects.
import ../../../..//Transactions/Transaction

#Serialization libs.
import SerializeMint
import ../../../../../Network/Serialize/Transactions/SerializeClaim
import ../../../../../Network/Serialize/Transactions/SerializeSend
import ../../../../../Network/Serialize/Transactions/SerializeData

#Serialize the TransactionObj.
proc serialize*(
    tx: Transaction
): string {.forceCheck: [].} =
    case tx:
        of Mint as mint:
            result = '\0' & mint.serialize()
        of Claim as claim:
            result = '\1' & claim.serialize()
        of Send as send:
            result = '\2' & send.serialize()
        of Data as data:
            result = '\3' & data.serialize()
