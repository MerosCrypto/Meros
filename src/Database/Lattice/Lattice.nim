#Errors and Util lib.
import ../../lib/Errors
import ../../lib/Util

#Numerical libs.
import ../../lib/BN

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
#Export the Index object/function.
export Index, newIndex, getAddress, getNonce
export LatticeMasterObj.Lattice, newLattice

#Add a Node to the Hash Lookup.
proc addToLookup(lattice: Lattice, node: Node) {.raises: [].} =
    lattice
        .getLookup()
        .add(
            node.getHash(),
            newIndex(
                node.getSender(),
                node.getNonce()
            )
        )

#Add a Node to the Lattice.
proc add*(lattice: Lattice, node: Node, mintOverride: bool = false): bool {.raises: [ValueError, Exception].} =
    #Make sure only this node creates mint TXs.
    if (
        (node.getSender() == "minter") and
        (not mintOverride)
    ):
        return false

    var
        blockLattice = lattice.getLattice() #Get the Block Lattice.
        account: Account = blockLattice.getAccount(node.getSender()) #Get the Account.

    case node.descendant:
        of NodeSend:
            #Cast the node.
            var send: Send = cast[Send](node)

            #Add it.
            result = account.add(
                #Send Node.
                send,
                #Transaction Difficulty.
                lattice.getDifficulties().getTransaction()
            )

        of NodeReceive:
            var recv: Receive = cast[Receive](node)

            result = account.add(
                #Receive Node.
                recv,
                #Supposed Send node.
                blockLattice
                    .getNode(
                        newIndex(
                            recv.getInputAddress(),
                            recv.getInputNonce()
                        )
                    )
            )

        of NodeData:
            var data: Data = cast[Data](node)

            result = account.add(
                #Data Node.
                data,
                #Data Difficulty.
                lattice.getDifficulties().getData()
            )

        of NodeVerification:
            var verif: Verification = cast[Verification](node)

            result = account.add(
                #Verification Node.
                verif
            )

        of NodeMeritRemoval:
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

proc mint*(lattice: Lattice, address: string, amount: BN): Index {.raises: [ResultError, ValueError, Exception].} =
    #Get the Height in a new var that won't update.
    var height: BN = newBN(lattice.getLattice().getAccount("minter").getHeight())

    #Create the Send Node.
    var send: Send = newSend(
        address,
        amount,
        height
    )
    #Mine it.
    send.mine(newBN())

    #Set the sender.
    if not send.setSender("minter"):
        raise newException(ResultError, "Couldn't set the minter as the sender.")

    #Add it to the Lattice.
    if not lattice.add(send, true):
        raise newException(ResultError, "Couldn't add the mint node to the Lattice.")

    #Return the Index.
    result = newIndex("minter", height)

#Get the Difficulties.
proc getTransactionDifficulty*(lattice: Lattice): BN {.raises: [].} =
    lattice.getDifficulties().getTransaction()
proc getDataDifficulty*(lattice: Lattice): BN {.raises: [].} =
    lattice.getDifficulties().getData()

#Getters for Account info.
proc getHeight*(lattice: Lattice, address: string): BN {.raises: [ValueError].} =
    lattice.getLattice().getAccount(address).getHeight()
proc getBalance*(lattice: Lattice, address: string): BN {.raises: [ValueError].} =
    lattice.getLattice().getAccount(address).getBalance()

#Getters for Nodes from the Lattice.
proc getNode*(lattice: Lattice, index: Index): Node {.raises: [ValueError].} =
    lattice.getLattice().getNode(index)
proc `[]`*(lattice: Lattice, index: Index): Node {.raises: [ValueError].} =
    lattice.getLattice().getNode(index)
proc getNode*(lattice: Lattice, hash: string): Node {.raises: [ValueError].} =
    lattice.getLattice().getNode(lattice.getLookup(), hash)

#Iterates over every hash the lookup table has.
iterator hashes*(lattice: Lattice): string {.raises: [].} =
    for hash in lattice.getLookup().hashes():
        yield hash
