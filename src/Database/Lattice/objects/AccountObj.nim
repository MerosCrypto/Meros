#BN lib.
import BN

#Node, Send, and Receive objects.
import NodeObj
import SendObj
import ReceiveObj

#Finals lib.
import finals

#Account object.
finalsd:
    type Account* = ref object of RootObj
        #Chain owner.
        address* {.final.}: string
        #Account height. BN for compatibility.
        height*: uint
        #seq of the TXs.
        nodes*: seq[Node]
        #Balance of the address.
        balance*: BN

#Creates a new account object.
func newAccountObj*(address: string): Account {.raises: [].} =
    Account(
        address: address,
        height: 0,
        nodes: @[],
        balance: newBN()
    )

#Add a Node to an account.
proc addNode*(
    account: Account,
    node: Node,
    dependent: Node
) {.raises: [].} =
    #Increase the account height and add the node.
    inc(account.height)
    account.nodes.add(node)

    case node.descendant:
        #If it's a Send Node...
        of NodeType.Send:
            #Cast it to a var.
            var send: Send = cast[Send](node)
            #Update the balance.
            account.balance -= send.amount
        #If it's a Receive Node...
        of NodeType.Receive:
            #Cast it to a var.
            var recv: Receive = cast[Receive](node)
            #Cast the matching Send.
            var send: Send = cast[Send](dependent)
            #Update the balance.
            account.balance += send.amount
        else:
            discard

#Helper getter that takes in an index.
func `[]`*(account: Account, index: uint): Node {.raises: [ValueError].} =
    if index >= uint(account.nodes.len):
        raise newException(ValueError, "Account index out of bounds.")

    result = account.nodes[int(index)]
