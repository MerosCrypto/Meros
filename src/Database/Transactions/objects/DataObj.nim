#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Transaction object.
import TransactionObj
export TransactionObj

#Data object.
type Data* = ref object of Transaction
    #Data stored in this Transaction.
    data*: string
    #Signature.
    signature*: EdSignature
    #Proof this isn't spam.
    proof*: uint32
    #Argon hash.
    argon*: ArgonHash

#Data constructor.
func newDataObj*(
    input: Hash[384],
    data: string
): Data {.forceCheck: [].} =
    #Create the Data.
    result = Data(
        inputs: @[
            newInput(input)
        ],
        data: data
    )

#Helper function to check if a Data is first.
proc isFirstData*(
    data: Data
): bool {.forceCheck: [].} =
    for b in 0 ..< 16:
        if data.inputs[0].hash.data[b] != 0:
            return false

    result = true
