#Numerical libs.
import ../../../lib/BN
import ../../../lib/Base

#Node object and node descendants.
import NodeObj
import TransactionObj
import VerificationObj
import MeritRemovalObj

#Account object.
type Account* = ref object of RootObj
    #Chain owner.
    address: string
    #Account height. BN for compatibility.
    height: BN
    #seq of the TXs.
    transactions: seq[Node]
    #Balance of the address.
    balance: BN

proc newAccountObj*(address: string): Account {.raises: [].} =
    Account(
        address: address,
        height: newBN(),
        transactions: @[],
        balance: newBN()
    )

proc addTransaction(account: Account, tx: Transaction): bool {.raises: [].} =
    discard

proc addVerification(account: Account, verif: Verification): bool {.raises: [].} =
    discard

proc addMeritRemoval(account: Account, mr: MeritRemoval): bool {.raises: [].} =
    discard

proc addNode*(account: Account, node: Node): bool {.raises: [].} =
    if newBN(account.transactions.len) != node.getNonce():
        result = false
        return

    case node.getDescendant():
        of 1:
            result = account.addTransaction(cast[Transaction](node))
        of 2:
            result = account.addVerification(cast[Verification](node))
        of 3:
            result = account.addMeritRemoval(cast[MeritRemoval](node))
        else:
            result = false

#Getters.
proc getAddress*(account: Account): string {.raises: [].} =
    account.address
proc getHeight*(account: Account): BN {.raises: [].} =
    account.height
proc getTransactions*(account: Account): seq[Node] {.raises: [].} =
    account.transactions
proc `[]`*(account: Account, index: int): Node {.raises: [].} =
    account.transactions[index]
proc getBalance*(account: Account): BN {.raises: [].} =
    account.balance
