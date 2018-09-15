#Numerical libs.
import BN as BNFile
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#Node object.
import NodeObj

#SetOnce lib.
import SetOnce

#Data object.
type Data* = ref object of Node
    #Data included in the TX.
    data*: SetOnce[string]
    #SHA512 hash.
    sha512*: SetOnce[SHA512Hash]
    #Proof this isn't spam.
    proof*: SetOnce[BN]

#New Data object.
proc newDataObj*(data: string): Data {.raises: [ValueError].} =
    result = Data()
    result.descendant.value = NodeType.Data
    result.data.value = data
