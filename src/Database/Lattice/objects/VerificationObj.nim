#Numerical lib.
import BN

#Hash lib.
import ../../../lib/Hash

#Node/transaction object.
import NodeObj

#SetOnce lib.
import SetOnce

type Verification* = ref object of Node
    #Send Hash.
    verified*: SetOnce[Hash[512]]

#New Verification object.
proc newVerificationObj*(verified: Hash[512]): Verification {.raises: [ValueError].} =
    result = Verification()
    result.descendant.value = NodeType.Verification
    result.verified.value = verified
