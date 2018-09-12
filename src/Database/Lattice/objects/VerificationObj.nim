#Numerical lib.
import BN

#Hash lib.
import ../../../lib/Hash

#Node/transaction object.
import NodeObj

type Verification* = ref object of Node
    #Send Hash.
    verified: Hash[512]

#New Verification object.
proc newVerificationObj*(verified: Hash[512]): Verification {.raises: [].} =
    Verification(
        descendant: NodeType.Verification,
        verified: verified
    )

#Getter.
proc getVerified*(verif: Verification): Hash[512] {.raises: [].} =
    verif.verified
