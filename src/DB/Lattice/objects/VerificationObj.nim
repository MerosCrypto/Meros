#Numerical libs.
import ../../../lib/BN
import ../../../lib/Base

#Node/transaction object.
import NodeObj
import TransactionObj

type Verification* = ref object of Node
    address: string
    index: BN
    txHash: string

    tx: Transaction
