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

    case node.descendant:
        of NodeSend:
            var send: Send = cast[Send](node)
            account.balance -= send.getAmount()
        of NodeReceive:
            var recv: Receive = cast[Receive](node)
            account.balance += recv.getAmount()
        else:
            discard

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
