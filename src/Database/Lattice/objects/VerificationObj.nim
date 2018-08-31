#Numerical libs.
import BN

#Node/transaction object.
import NodeObj

type Verification* = ref object of Node
    #Address/nonce.
    address: string
    index: BN
    #Send Hash.
    verified: string

#New Verification object.
proc newVerificationObj*(address: string, index: BN, verified: string): Verification =
    Verification(
        descendant: NodeVerification,
        address: address,
        index: index,
        verified: verified
    )

#Getters.
proc getAddress*(verif: Verification): string =
    verif.address
proc getIndex*(verif: Verification): BN =
    verif.index
proc getVerified*(verif: Verification): string =
    verif.verified
