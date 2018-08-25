#Util lib.
import ../../../lib/Util

#BN lib.
import ../../../lib/BN

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
    result.difficulties.setTransaction(newBN("".pad(64, "88")))
    result.difficulties.setData(newBN("".pad(64, "88")))

    #Add the minter account.
    discard result.lattice.newAccount("minter")

proc getDifficulties*(lattice: Lattice): Difficulties {.raises: [].} =
    lattice.difficulties
proc getLattice*(lattice: Lattice): BlockLattice {.raises: [].} =
    lattice.lattice
proc getLookup*(lattice: Lattice): HashLookup {.raises: [].} =
    lattice.lookup
