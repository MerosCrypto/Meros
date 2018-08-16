#Numerical libs.
import ../../../lib/BN

#Node/transaction object.
import NodeObj
import TransactionObj

type Verification* = ref object of Node
    #Address/nonce.
    address: string
    index: BN
    #TX Hash.
    tx: string

#New Verification object.
proc newVerificationObj*(address: string, index: BN, tx: string): Verification =
    Verification(
        address: address,
        index: index,
        tx: tx
    )

#Getters.
proc getAddress*(verif: Verification): string =
    verif.address
proc getIndex*(verif: Verification): BN =
    verif.index
proc getTransaction*(verif: Verification): string =
    verif.tx
