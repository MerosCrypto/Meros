#BN lib.
import ../../lib/BN

#Node object and descendants.
import objects/NodeObj
import objects/TransactionObj
import objects/DataObj
import objects/VerificationObj
import objects/MeritRemovalObj

#Account object.
import objects/AccountObj
export AccountObj

#Create a new Account.
proc newAccount*(address: string): Account {.raises: [ValueError].} =
    newAccountObj(address)

#Add a Transaction.
proc addTransaction(account: Account, tx: Transaction): bool {.raises: [].} =
    discard

#Add Data.
proc addData(account: Account, data: Data): bool {.raises: [].} =
    discard

#Add a Verification.
proc addVerification(account: Account, verif: Verification): bool {.raises: [].} =
    discard

#Add a Merit Removal.
proc addMeritRemoval(account: Account, mr: MeritRemoval): bool {.raises: [].} =
    discard

#Add a node.
proc addNode*(account: Account, node: Node): bool {.raises: [].} =
    #Verify the nonce.
    if newBN(account.getNodes().len) != node.getNonce():
        result = false
        return

    #Work off the type of descendant.
    case node.getDescendant():
        #If it's a Transaction...
        of 1:
            result = account.addTransaction(cast[Transaction](node))
        #If it's Data...
        of 2:
            result = account.addData(cast[Data](node))
        #If it's a Verification...
        of 3:
            result = account.addVerification(cast[Verification](node))
        #If it's a Merit Removal..
        of 4:
            result = account.addMeritRemoval(cast[MeritRemoval](node))
        #Else, return false...
        else:
            result = false
