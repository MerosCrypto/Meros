#Errors lib.
import ../../../lib/Errors

#Numerical libs.
import BN
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#Index object.
import IndexObj

#Node object.
import NodeObj

#Account object.
import AccountObj

#Tables standard library.
import tables

#Lattice master object.
type Lattice* = ref object of RootObj
    #Difficulties.
    difficulties*: tuple[transaction: BN, data: BN]

    #Block Lattice object.
    lattice*: TableRef[
        string,
        Account
    ]

    #Lookup table.
    lookup*: TableRef[
        string,
        Index
    ]

#Lattice constructor
proc newLattice*(
    txDiff: string,
    dataDiff: string
): Lattice {.raises: [ValueError].} =
    #Create the object.
    result = Lattice(
        difficulties: (transaction: txDiff.toBN(16), data: dataDiff.toBN(16)),
        lattice: newTable[string, Account](),
        lookup: newTable[string, Index]()
    )

    #Add the minter account.
    result.lattice["minter"] = newAccountObj("minter")

#Creates a new Account on the Lattice.
proc addAccount*(
    lattice: Lattice,
    address: string
): bool {.raises: [].} =
    result = true
    #Make sure the account doesn't already exist.
    if lattice.lattice.hasKey(address):
        return false

    lattice.lattice[address] = newAccountObj(address)

#Add a hash to the lookup.
proc addHash*(
    lattice: Lattice,
    hash: Hash[512],
    index: Index
) {.raises: [].} =
    lattice.lookup[$hash] = index

#Gets an account.
proc getAccount*(
    lattice: Lattice,
    address: string
): Account {.raises: [ValueError].} =
    #Call newAccount, which will only create an account if one doesn't exist.
    discard lattice.addAccount(address)

    #Return the account.
    result = lattice.lattice[address]

#Gets a Node by its Index.
proc `[]`*(lattice: Lattice, index: Index): Node {.raises: [ValueError].} =
    if not lattice.lattice.hasKey(index.address):
        raise newException(ValueError, "Lattice does not have an Account for that address.")
    if lattice.lattice[index.address].height <= index.nonce:
        raise newException(ValueError, "The Account for that address doesn't have a Node for that nonce.")

    result = lattice.lattice[index.address][index.nonce.toInt()]

#Gets a Node by its hash.
proc getNode*(lattice: Lattice, hash: string): Node {.raises: [ValueError].} =
    if not lattice.lookup.hasKey(hash):
        raise newException(ValueError, "Lattice does not have a node for that hash.")

    result = lattice[lattice.lookup[hash]]
