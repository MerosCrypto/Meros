#Errors lib.
import ../../../../../lib/Errors

#Hash lib.
import ../../../../../lib/Hash

#Transaction objects.
import ../../../..//Transactions/Transaction

#Serialization libs.
import ParseMint
import ../../../../../Network/Serialize/Transactions/ParseClaim
import ../../../../../Network/Serialize/Transactions/ParseSend
import ../../../../../Network/Serialize/Transactions/ParseData

#Serialize the TransactionObj.
proc parseTransaction*(
    hash: Hash[384],
    tx: string
): Transaction {.forceCheck: [
    ValueError,
    EdPublicKeyError
].} =
    case tx[0]:
        of '\0':
            result = hash.parseMint(tx.substr(1))

        of '\1':
            try:
                result = tx.substr(1).parseClaim()
            except ValueError as e:
                raise e
            except EdPublicKeyError as e:
                raise e

        of '\2':
            try:
                result = tx.substr(1).parseSend(Hash[384]())
            except ValueError as e:
                raise e
            except EdPublicKeyError as e:
                raise e
            except Spam:
                doAssert(false, "parseSend believes a Hash is less than 0.")

        of '\3':
            try:
                result = tx.substr(1).parseData(Hash[384]())
            except ValueError as e:
                raise e
            except Spam:
                doAssert(false, "parseData believes a Hash is less than 0.")

        else:
            doAssert(false, "Invalid Transaction Type loaded from the Database: " & $int(tx[0]))
