#Number libs.
import BN
import ../lib/Base

#Time lib.
import ../lib/Time

#Node and Difficulty libs.
import Node as NodeFile

#Lists standard lib.
import lists

#Nodechain object.
type Nodechain* = ref object of RootObj
    #Chain owner.
    address: string
    #Nodechain height. BN for compatibility.
    height: BN
    #Doubly Linked List of all the nodes.
    nodes: DoublyLinkedList[Node]
    #Balance of the addres.
    balance: BN

#Create a new Nodechain.
proc newNodechain*(address: string): Nodechain {.raises: [].} =
    #Init the object.
    result = Nodechain(
        address: address,
        height: newBN(0),
        nodes: initDoublyLinkedList[Node](),
        balance: newBN(0)
    )

proc getNodes*(nodechain: Nodechain): DoublyLinkedList[Node] {.raises: [].} =
    result = nodechain.nodes

iterator getNodes*(nodechain: Nodechain): Node {.raises: [].} =
    for i in nodechain.nodes.items():
        yield i
