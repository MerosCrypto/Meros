#Import the Lattice Objects.
import objects/LatticeObjs

type Lattice = ref object of RootObj
    #Difficulties.
    difficulties: Difficulties
    #Block Lattice object.
    lattice: BlockLattice
    #Lookup table.
    lookup: HashLookup
