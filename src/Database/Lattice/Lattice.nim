#Util lib.
import ../../lib/Util

#Numerical libs.
import ../../lib/BN

#Node and node descendants.
import objects/NodeOBj
import Send
import Receive
import Data
import Verification
import MeritRemoval

#Lattice Objects.
import objects/LatticeObjs
import objects/LatticeMasterObj
#Export the Index object/function.
export Index, newIndex, getAddress, getIndex
export newLattice

#Add a Node.
proc add*(lattice: Lattice, node: Node): bool {.raises: [].} =
    discard

#Add a Send Node.
proc add*(lattice: Lattice, send: Send): bool {.raises: [].} =
    discard

#Add a Receive Node.
proc add*(lattice: Lattice, recv: Receive): bool {.raises: [].} =
    discard

#Add a Data Node.
proc add*(lattice: Lattice, data: Data): bool {.raises: [].} =
    discard

#Add a Verification Node.
proc add*(lattice: Lattice, verif: Verification): bool {.raises: [].} =
    discard

#Add a MeritRemoval Node.
proc add*(lattice: Lattice, mr: MeritRemoval): bool {.raises: [].} =
    discard

#Get the Difficulties.
proc getTransactionDifficulty*(lattice: Lattice): BN {.raises: [].} =
    lattice.getDifficulties().getTransaction()
proc getDataDifficulty*(lattice: Lattice): BN {.raises: [].} =
    lattice.getDifficulties().getData()

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
