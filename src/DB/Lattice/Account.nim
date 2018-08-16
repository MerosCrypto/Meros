#BN lib.
import ../../lib/BN

#Node object and descendants.
import objects/NodeObj
import objects/TransactionObj
import objects/VerificationObj
import objects/MeritRemovalObj

#Account object.
import objects/AccountObj
export AccountObj

#Create a new Account.
proc newAccount*(address: string): Account {.raises: [].} =
    newAccountObj(address)

proc addTransaction(account: Account, tx: Transaction): bool {.raises: [].} =
    discard

proc addVerification(account: Account, verif: Verification): bool {.raises: [].} =
    discard

proc addMeritRemoval(account: Account, mr: MeritRemoval): bool {.raises: [].} =
    discard

proc addNode*(account: Account, node: Node): bool {.raises: [].} =
    if newBN(account.getTransactions().len) != node.getNonce():
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
