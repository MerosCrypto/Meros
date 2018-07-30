#Number libs.
import BN
import ../lib/Base

#Time lib.
import ../lib/Time

#Transaction and Difficulty libs.
import Transaction as TransactionFile

#Lists standard lib.
import lists

#Account object.
type Account* = ref object of RootObj
    #Chain owner.
    address: string
    #Account height. BN for compatibility.
    height: BN
    #Doubly Linked List of all the nodes.
    nodes: DoublyLinkedList[Transaction]
    #Balance of the addres.
    balance: BN

#Create a new Account.
proc newAccount*(address: string): Account {.raises: [].} =
    #Init the object.
    result = Account(
        address: address,
        height: newBN(),
        nodes: initDoublyLinkedList[Transaction](),
        balance: newBN()
    )

proc getTransactions*(nodechain: Account): DoublyLinkedList[Transaction] {.raises: [].} =
    result = nodechain.nodes

iterator getTransactions*(nodechain: Account): Transaction {.raises: [].} =
    for i in nodechain.nodes.items():
        yield i
