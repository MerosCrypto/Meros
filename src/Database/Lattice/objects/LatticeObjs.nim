#BN lib.
import BN

#Node object.
import NodeObj

#Account object.
import AccountObj

#Tables standard library.
import tables

type
    #Index object. Specifies a Node on the Lattice.
    Index* = ref object of RootObj
        address: string
        nonce: BN

    #Lattice Difficulties object. Specifies the TX/Data  difficulties.
    Difficulties* = ref object of RootObj
        transaction: BN
        data: BN

    #Block Lattice object.
    BlockLattice* = TableRef[
        string,
        Account
    ]

    #Hash Lookup object. Maps a hash to an index.
    HashLookup* = TableRef[
        string,
        Index
    ]

#Constructors.
proc newIndex*(address: string, nonce: BN): Index {.raises: [].} =
    Index(
        address: address,
        nonce: nonce
    )
proc newDifficulties*(): Difficulties {.raises: [].} =
    result = Difficulties(
        transaction: newBN(),
        data: newBN()
    )
proc newBlockLattice*(): BlockLattice {.raises: [].} =
    newTable[string, Account]()
proc newHashLookup*(): HashLookup {.raises: [].} =
    newTable[string, Index]()

#Set difficulty functions.
proc setTransaction*(difficulties: Difficulties, tx: BN) {.raises: [].} =
    difficulties.transaction = tx
proc setData*(difficulties: Difficulties, data: BN) {.raises: [].} =
    difficulties.data = data

#Creates a new account on the lattice.
proc newAccount*(lattice: BlockLattice, address: string): bool {.raises: [].} =
    result = true
    if lattice.hasKey(address):
        return false

    lattice[address] = newAccountObj(address)

#Adds a hash to the lookup.
proc add*(lookup: HashLookup, hash: string, index: Index) {.raises: [].} =
    lookup[hash] = index

#Getters.
#Gets the Index data.
proc getAddress*(index: Index): string {.raises: [].} =
    index.address
proc getNonce*(index: Index): BN {.raises: [].} =
    index.nonce

#Gets the difficulties.
proc getTransaction*(diff: Difficulties): BN {.raises: [].} =
    diff.transaction
proc getData*(diff: Difficulties): BN {.raises: [].} =
    diff.data

#Gets an account.
proc getAccount*(lattice: BlockLattice, address: string): Account {.raises: [ValueError].} =
    #If the Lattice doesn't have a blockchain for that account...
    if not lattice.hasKey(address):
        #Create it, but if that fails...
        if not lattice.newAccount(address):
            #Raise an exception.
            raise newException(ValueError, "Couldn't create an account on the Lattice.")

    result = lattice[address]
#Gets a node by its index.
proc getNode*(lattice: BlockLattice, index: Index): Node {.raises: [ValueError].} =
    if not lattice.hasKey(index.address):
        raise newException(ValueError, "Lattice does not have a blockchain for that address.")

    result = lattice[index.address][index.nonce.toInt()]
#Gets a node via [].
proc `[]`*(lattice: BlockLattice, index: Index): Node {.raises: [ValueError].} =
    lattice.getNode(index)
#Gets a node by its hash.
proc getNode*(lattice: BlockLattice, lookup: HashLookup, hash: string): Node {.raises: [ValueError].} =
    if not lookup.hasKey(hash):
        raise newException(ValueError, "Lattice does not have a node for that hash.")

    result = lattice.getNode(lookup[hash])

#Iterates over every hash the lookup table has.
iterator hashes*(lookup: HashLookup): string {.raises: [].} =
    for hash in lookup.keys():
        yield hash
