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
    difficulties*: Difficulties
    #Block Lattice object.
    lattice*: BlockLattice
    #Lookup table.
    lookup*: HashLookup

#Constructor.
proc newLattice*(): Lattice {.raises: [ValueError].} =
    #Create the object.
    result = Lattice(
        difficulties: newDifficulties(),
        lattice: newBlockLattice(),
        lookup: newHashLookup()
    )

    #Set the difficulty values.
    result.difficulties.transaction = "".pad(128, "aa").toBN(16)
    result.difficulties.data = "".pad(128, "cc").toBN(16)

    #Add the minter account.
    discard result.lattice.newAccount("minter")
