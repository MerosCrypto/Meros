#Errors lib.
import ../../../../../lib/Errors

#Transaction objects.
import ../../../..//Transactions/Transaction

#Serialization libs.
import ParseMint
import ../../../../../Network/Serialize/Transactions/ParseClaim
import ../../../../../Network/Serialize/Transactions/ParseSend
import ../../../../../Network/Serialize/Transactions/ParseData

#Serialize the TransactionObj.
proc parseTransaction*(
    tx: string
): Transaction {.forceCheck: [
    ValueError,
    EdPublicKeyError,
    BLSError
].} =
    case tx[0]:
        of '\0':
            try:
                result = tx.substr(1).parseMint()
            except BLSError as e:
                fcRaise e

        of '\1':
            try:
                result = tx.substr(1).parseClaim()
            except ValueError as e:
                fcRaise e
            except EdPublicKeyError as e:
                fcRaise e
            except BLSError as e:
                fcRaise e

        of '\2':
            try:
                result = tx.substr(1).parseSend()
            except ValueError as e:
                fcRaise e
            except EdPublicKeyError as e:
                fcRaise e

        of '\3':
            try:
                result = tx.substr(1).parseData()
            except ValueError as e:
                fcRaise e

        else:
            doAssert(false, "Invalid Transaction Type loaded from the Database: " & $int(tx[0]))
