import Node
import Transaction

type Verification* = ref object of Node
    tx: Transaction
