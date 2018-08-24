#Numerical libs.
import ../../../lib/BN

#Node/transaction object.
import NodeObj

type Verification* = ref object of Node
    #Address/nonce.
    address: string
    index: BN
    #Send Hash.
    send: string

#New Verification object.
proc newVerificationObj*(address: string, index: BN, send: string): Verification =
    Verification(
        descendant: NodeVerification,
        address: address,
        index: index,
        send: send
    )

#Getters.
proc getAddress*(verif: Verification): string =
    verif.address
proc getIndex*(verif: Verification): BN =
    verif.index
proc getSend*(verif: Verification): string =
    verif.send
