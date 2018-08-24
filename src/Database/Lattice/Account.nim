#BN lib.
import ../../lib/BN

#Node object and descendants.
import objects/NodeObj
import objects/SendObj
import objects/ReceiveObj
import objects/DataObj
import objects/VerificationObj
import objects/MeritRemovalObj

#Account object.
import objects/AccountObj
export AccountObj

#Create a new Account.
proc newAccount*(address: string): Account {.raises: [ValueError].} =
    newAccountObj(address)

#Add a Send.
proc addSend(account: Account, send: Send): bool {.raises: [].} =
    discard

#Add a Send.
proc addReceive(account: Account, recv: Receive): bool {.raises: [].} =
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
    case node.descendant:
        #If it's a Send...
        of NodeSend:
            result = account.addSend(cast[Send](node))
        #If it's a Receive...
        of NodeReceive:
            result = account.addReceive(cast[Receive](node))
        #If it's Data...
        of NodeData:
            result = account.addData(cast[Data](node))
        #If it's a Verification...
        of NodeVerification:
            result = account.addVerification(cast[Verification](node))
        #If it's a Merit Removal..
        of NodeMeritRemoval:
            result = account.addMeritRemoval(cast[MeritRemoval](node))
        #Else, return false...
        else:
            result = false
