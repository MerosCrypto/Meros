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
        #Send Hash.
        verified* {.final.}: Hash[512]

#New Verification object.
proc newVerificationObj*(verified: Hash[512]): Verification {.raises: [FinalAttributeError].} =
    result = Verification(
        verified: verified
    )
    result.descendant = NodeType.Verification
