#Numerical libs.
import BN

#Node/transaction object.
import NodeObj

type Verification* = ref object of Node
    #Send Hash.
    verified: string

#New Verification object.
proc newVerificationObj*(verified: string): Verification {.raises: [].} =
    Verification(
        descendant: NodeType.Verification,
        verified: verified
    )

#Getter.
proc getVerified*(verif: Verification): string {.raises: [].} =
    verif.verified
