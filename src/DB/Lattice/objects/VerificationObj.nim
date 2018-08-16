#Numerical libs.
import ../../../lib/BN

#Node/transaction object.
import NodeObj
import TransactionObj

type Verification* = ref object of Node
    address: string
    index: BN
    txHash: string

    tx: Transaction
