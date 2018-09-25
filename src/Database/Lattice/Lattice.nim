#Errors.
import ../../lib/Errors

#BN lib.
import BN

#Node and node descendants.
import objects/NodeObj
import Send
import Receive
import Data
import Verification
import MeritRemoval
#Export the Node and Node descendants.
export NodeObj
export Send
export Receive
export Data
export Verification
export MeritRemoval

#Account lib.
import Account

#Lattice Objects.
import objects/LatticeObjs
import objects/LatticeMasterObj
#Export the Index object/constructor.
export Index, newIndex
#Export the Lattice object/constructor.
export LatticeMasterObj.Lattice, newLattice

#Finals lib.
import finals

#Add a Node to the Hash Lookup.
proc addToLookup(lattice: Lattice, node: Node) {.raises: [].} =
    lattice
        .lookup
        .add(
            $node.hash,
            newIndex(
                node.sender,
                node.nonce
            )
        )

#Add a Node to the Lattice.
proc add*(
    lattice: Lattice,
    node: Node,
    mintOverride: bool = false
): bool {.raises: [ValueError].} =
    #Make sure only this node creates mint TXs.
    if (
        (node.sender == "minter") and
        (not mintOverride)
    ):
        return false

    var
        blockLattice = lattice.lattice #Get the Block Lattice.
        account: Account = blockLattice.getAccount(node.sender) #Get the Account.

    case node.descendant:
        of NodeType.Send:
            #Cast the node.
            var send: Send = cast[Send](node)

            #Add it.
            result = account.add(
                #Send Node.
                send,
                #Transaction Difficulty.
                lattice.difficulties.transaction
            )

        of NodeType.Receive:
            var recv: Receive = cast[Receive](node)

            result = account.add(
                #Receive Node.
                recv,
                #Supposed Send node.
                blockLattice
                    .getNode(
                        newIndex(
                            recv.inputAddress,
                            recv.inputNonce
                        )
                    )
            )

        of NodeType.Data:
            var data: Data = cast[Data](node)

            result = account.add(
                #Data Node.
                data,
                #Data Difficulty.
                lattice.difficulties.data
            )

        of NodeType.Verification:
            var verif: Verification = cast[Verification](node)

            result = account.add(
                #Verification Node.
                verif
            )

        of NodeType.MeritRemoval:
            var mr: MeritRemoval = cast[MeritRemoval](node)

            result = account.add(
                #Data Node.
                mr
            )

    #If that didn't work, return.
    if not result:
        return

    #Else, add the node to the lookup table.
    lattice.addToLookup(node)

proc mint*(
    lattice: Lattice,
    address: string,
    amount: BN
): Index {.raises: [ResultError, ValueError, FinalAttributeError].} =
    #Get the Height in a new var that won't update.
    var height: BN = lattice.lattice.getAccount("minter").height

    #Create the Send Node.
    var send: Send = newSend(
        address,
        amount,
        height
    )
    #Mine it.
    send.mine(newBN())

    #Set the sender.
    send.sender = "minter"

    #Add it to the Lattice.
    if not lattice.add(send, true):
        raise newException(ResultError, "Couldn't add the mint node to the Lattice.")

    #Return the Index.
    result = newIndex("minter", height)

#Getters for Account info.
proc getHeight*(lattice: Lattice, address: string): BN {.raises: [ValueError].} =
    lattice.lattice.getAccount(address).height
proc getBalance*(lattice: Lattice, address: string): BN {.raises: [ValueError].} =
    lattice.lattice.getAccount(address).balance

#Getters for Nodes from the Lattice.
proc getNode*(lattice: Lattice, index: Index): Node {.raises: [ValueError].} =
    lattice.lattice.getNode(index)
proc `[]`*(lattice: Lattice, index: Index): Node {.raises: [ValueError].} =
    lattice.lattice.getNode(index)
proc getNode*(lattice: Lattice, hash: string): Node {.raises: [ValueError].} =
    lattice.lattice.getNode(lattice.lookup, hash)

#Iterates over every hash the lookup table has.
iterator hashes*(lattice: Lattice): string {.raises: [].} =
    for hash in lattice.lookup.hashes():
        yield hash
