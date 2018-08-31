#Util lib.
import ../../../lib/Util

#Numerical libs.
import BN
import ../../../lib/Base

#Lattice objects.
import LatticeObjs

#Lattice master object.
type Lattice* = ref object of RootObj
    #Difficulties.
    difficulties: Difficulties
    #Block Lattice object.
    lattice: BlockLattice
    #Lookup table.
    lookup: HashLookup

#Constructor.
proc newLattice*(): Lattice {.raises: [ValueError].} =
    #Create the object.
    result = Lattice(
        difficulties: newDifficulties(),
        lattice: newBlockLattice(),
        lookup: newHashLookup()
    )

    #Set the difficulty values.
    result.difficulties.setTransaction("".pad(64, "88").toBN(16))
    result.difficulties.setData("".pad(64, "aa").toBN(16))

    #Add the minter account.
    discard result.lattice.newAccount("minter")

proc getDifficulties*(lattice: Lattice): Difficulties {.raises: [].} =
    lattice.difficulties
proc getLattice*(lattice: Lattice): BlockLattice {.raises: [].} =
    lattice.lattice
proc getLookup*(lattice: Lattice): HashLookup {.raises: [].} =
    lattice.lookup
