#Util lib.
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

#Account lib.
import Account

#Lattice Objects.
import objects/LatticeObjs
import objects/LatticeMasterObj
#Export the Index object/function.
export Index, newIndex, getAddress, getIndex
export newLattice

#Add a Node to the Hash Lookup.
proc addToLookup(lattice: Lattice, node: Node): bool {.raises: [ValueError].} =
    lattice
        .getLookup()
        .add(
            node.getHash(),
            newIndex(
                node.getSender(),
                node.getNonce().toInt()
            )
        )

#Add a Node to the Lattice.
proc add*(lattice: Lattice, node: Node) {.raises: [ValueError, Exception].} =
    var
        result: bool
        account: Account = lattice
            #Get the BlockLattice.
            .getLattice()
            #Get the account.
            .getAccount(
                node.getSender()
            )

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
                lattice
                    .getLattice()
                    .getNode(
                        newIndex(
                            recv.getInputAddress(),
                            recv.getInputNonce().toInt()
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

    #This function will raise an error over returning bools.
    #The functions below it (in the hierarchy, not in the file) do the same.
    #That's fine within the Lattice scope, but this file is in the global scope.
    #It had to do one or the other, and I rather put a try/catch elsewhere than one here.
    #Therefore, it's optional, not forced by the Lattice library.

    #If that didn't work, raise a ValueError.
    if not result:
        raise newException(ValueError, "Node couldn't be added to the Lattice.")

    #Else, add the node to the lookup table.
    result = lattice.addToLookup(node)
    if not result:
        #If that failed, raise a ValueError.
        raise newException(ValueError, "Node couldn't be added to the Lookup Table. The Lookup Table now is missing nodes on the Lattice. This is possibly from a hash collision.")

    #Everything's good! `result` should be true, but this function returns void.

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
