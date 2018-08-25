#Numerical libs.
import ../../../lib/BN
import ../../../lib/Base

#Node, Send, and Receive objects.
import NodeObj
import SendObj
import ReceiveObj

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

#Creates a new account object.
proc newAccountObj*(address: string): Account {.raises: [ValueError].} =
    Account(
        address: address,
        height: newBN(),
        nodes: @[],
        balance: newBN()
    )

#Add a Node to an account.
proc addNode*(account: Account, node: Node) {.raises: [ValueError].} =
    #Increase the account height and add the node.
    inc(account.height)
    account.nodes.add(node)

    case node.descendant:
        #If it's a Send Node...
        of NodeSend:
            #Update the balance.
            account.balance -= cast[Send](node).getAmount()
        #If it's a Receive Node...
        of NodeReceive:
            #Update the balance.
            account.balance += cast[Receive](node).getAmount()
        else:
            discard

#Getters.
proc getAddress*(account: Account): string {.raises: [].} =
    account.address
proc getHeight*(account: Account): BN {.raises: [].} =
    account.height
proc getNodes*(account: Account): seq[Node] {.raises: [].} =
    account.nodes
proc `[]`*(account: Account, index: int): Node {.raises: [ValueError].} =
    if index >= account.nodes.len:
        raise newException(ValueError, "Account index out of bounds.")

    result = account.nodes[index]
proc getBalance*(account: Account): BN {.raises: [].} =
    account.balance
