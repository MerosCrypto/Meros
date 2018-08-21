#Numerical libs.
import ../../../lib/BN
import ../../../lib/Base

#Node object and transaction object.
import NodeObj
import TransactionObj

#Account object.
type Account* = ref object of RootObj
    #Chain owner.
    address: string
    #Account height. BN for compatibility.
    height: BN
    #seq of the TXs.
    nodes: seq[Node]
    #Balance of the address.
    balance: BN

proc newAccountObj*(address: string): Account {.raises: [ValueError].} =
    Account(
        address: address,
        height: newBN(),
        nodes: @[],
        balance: newBN()
    )

proc add*(account: Account, node: Node): bool {.raises: [ValueError].} =
    inc(account.height)
    account.nodes.add(node)

    if node.getDescendant() == 1:
        var tx: Transaction = cast[Transaction](node)
        if tx.getInput() == account.address:
            account.balance -= tx.getAmount()
        elif tx.getOutput() == account.address:
            account.balance += tx.getAmount()
        else:
            raise newException(ValueError, "Trying to add a node to an unrelated account.")

#Getters.
proc getAddress*(account: Account): string {.raises: [].} =
    account.address
proc getHeight*(account: Account): BN {.raises: [].} =
    account.height
proc getNodes*(account: Account): seq[Node] {.raises: [].} =
    account.nodes
proc `[]`*(account: Account, index: int): Node {.raises: [].} =
    account.nodes[index]
proc getBalance*(account: Account): BN {.raises: [].} =
    account.balance
