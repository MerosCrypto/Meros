#Errors lib.
import ../../../../lib/Errors

#Transaction objects.
import ../../../../Database/Transactions/objects/MintObj
import ../../../../Database/Transactions/objects/ClaimObj
import ../../../../Database/Transactions/objects/SendObj

#Serialization libs.
import ParseMint
import ../../../../Network/Serialize/Transactions/ParseClaim
import ../../../../Network/Serialize/Transactions/ParseSend

#Serialize the TransactionObj.
proc parseTransaction*(
    tx: string
): Transaction {.forceCheck: [
    ValueError,
    ArgonError,
    EdPublicKeyError,
    BLSError
].} =
    case TransactionType(tx[0]):
        of TransactionType.Mint:
            try:
                result = tx.substr(1).parseMint()
            except BLSError as e:
                fcRaise e
        of TransactionType.Claim:
            try:
                result = tx.substr(1).parseClaim()
            except ValueError as e:
                fcRaise e
            except EdPublicKeyError as e:
                fcRaise e
            except BLSError as e:
                fcRaise e
        of TransactionType.Send:
            try:
                result = tx.substr(1).parseSend()
            except ValueError as e:
                fcRaise e
            except ArgonError as e:
                fcRaise e
            except EdPublicKeyError as e:
                fcRaise e
