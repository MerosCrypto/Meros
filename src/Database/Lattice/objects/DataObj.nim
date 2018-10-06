#Numerical libs.
import BN as BNFile
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#Node object.
import NodeObj

#Finals lib.
import finals

#Data object.
finalsd:
    type Data* = ref object of Node
        #Data included in the TX.
        data* {.final.}: string
        #SHA512 hash.
        sha512* {.final.}: SHA512Hash
        #Proof this isn't spam.
        proof* {.final.}: BN

#New Data object.
func newDataObj*(data: string): Data {.raises: [FinalAttributeError].} =
    result = Data(
        data: data
    )
    result.descendant = NodeType.Data
