#Numerical lib.
import BN

#Hash lib.
import ../../../lib/Hash

#Node/transaction object.
import NodeObj

#Finals lib.
import finals

finalsd:
    type Verification* = ref object of Node
        #Node Hash.
        verifies* {.final.}: Hash[512]

#New Verification object.
func newVerificationObj*(
    verifies: Hash[512]
): Verification {.raises: [FinalAttributeError].} =
    result = Verification(
        verifies: verifies
    )
    result.descendant = NodeType.Verification
