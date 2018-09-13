#Numerical libs.
import BN as BNFile
import ../../../lib/Base

#Node object.
import NodeObj

#SetOnce lib.
import SetOnce

#Data object.
type Data* = ref object of Node
    #Data included in the TX.
    data*: SetOnce[seq[uint8]]
    #SHA512 hash.
    sha512*: SetOnce[string]
    #Proof this isn't spam.
    proof*: SetOnce[BN]

#New Data object.
proc newDataObj*(data: seq[uint8]): Data {.raises: [ValueError].} =
    result = Data()
    result.descendant.value = NodeType.Data
    result.data.value = data
