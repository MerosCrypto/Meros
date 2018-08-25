#BN lib.
import ../../../lib/BN

#Node object.
import NodeObj

#Account object.
import AccountObj

#Tables standard library.
import tables

type
    #Lattice Difficulties object.
    Difficulties* = ref object of RootObj
        transaction: BN
        data: BN

    #Block Lattice object.
    BlockLattice* = TableRef[
        string,
        Account
    ]

    #Index object.
    Index* = ref object of RootObj
        address: string
        index: int

    #Hash Lookup object. Maps a hash to an index.
    HashLookup* = TableRef[
        string,
        Index
    ]

#Constructors.
proc newDifficulties*(tx: BN, data: BN): Difficulties =
    Difficulties()
proc newBlockLattice*(): BlockLattice =
    newTable[string, Account]()
proc newIndex*(address: string, index: int): Index =
    Index(
        address: address,
        index: index
    )
proc newHashLookup*(): HashLookup =
    newTable[string, Index]()

#Update difficulty functions.
proc updateDifficulties*(difficulties: Difficulties, tx: BN, data: BN) {.raises: [].} =
    difficulties.transaction = tx
    difficulties.data = data

#Creates a new account on the lattice.
proc newAccount*(lattice: BlockLattice, address: string): bool {.raises: [ValueError].} =
    result = true
    if lattice.hasKey(address):
        result = false
        return

    lattice[address] = newAccountObj(address)

#Adds a hash to the lookup.
proc addHash*(lookup: HashLookup, hash: string, index: Index): bool {.raises: [].} =
    result = true
    if lookup.hasKey(hash):
        result = false
        return

    lookup[hash] = index

#Gets the difficulties.
proc getTransaction*(diff: Difficulties): BN {.raises: [].} =
    diff.transaction
proc getData*(diff: Difficulties): BN {.raises: [].} =
    diff.data

#Gets an account.
proc `[]`*(lattice: BlockLattice, address: string): Account {.raises: [ValueError].} =
    if not lattice.hasKey(address):
        raise newException(ValueError, "Lattice does not have a blockchain for that address.")

    result = lattice[address]
#Gets a node by its index.
proc getNode*(lattice: BlockLattice, index: Index): Node {.raises: [ValueError].} =
    if not lattice.hasKey(index.address):
        raise newException(ValueError, "Lattice does not have a blockchain for that address.")

    result = lattice[index.address][index.index]
#Gets a node by its hash.
proc getNode*(lattice: BlockLattice, lookup: HashLookup, hash: string): Node {.raises: [ValueError].} =
    if not lookup.hasKey(hash):
        raise newException(ValueError, "Lattice does not have a node for that hash.")

    result = lattice.getNode(lookup[hash])

#Gets the Index data.
proc getAddress*(index: Index): string {.raises: [].} =
    index.address
proc getIndex*(index: Index): int {.raises: [].} =
    index.index

#Iterates over every hash the lookup has.
iterator hashes*(lookup: HashLookup): string {.raises: [].} =
    for hash in lookup.keys():
        yield hash
