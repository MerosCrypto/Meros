#Errors lib.
import ../../../lib/Errors

#Numerical libs.
import BN
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#Merit lib.
import ../../Merit/Merit

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Index object.
import ../../common/objects/IndexObj

#Entry object.
import EntryObj

#Account object.
import AccountObj

#BLS lib.
import ../../../lib/BLS

#Tables standard library.
import tables

#Lattice master object.
type Lattice* = ref object of RootObj
    #Database.
    db: DatabaseFunctionBox,
    
    accountsStr: string
    accountsSeq: seq[string]

    #Difficulties.
    difficulties*: tuple[transaction: BN, data: BN]

    #Lookup table (hash -> index).
    lookup*: TableRef[
        string,
        Index
    ]

    #Verifications (hash -> list of addresses who signed off on it).
    verifications*: TableRef[
        string,
        seq[BLSPublicKey]
    ]

    #Accounts (address -> account).
    accounts*: TableRef[
        string,
        Account
    ]

#Lattice constructor
func newLatticeObj*(
    db: DatabaseFunctionBox,
    txDiff: string,
    dataDiff: string
): Lattice {.raises: [ValueError].} =
    #Create the object.
    result = Lattice(
        db: db,

        difficulties: (transaction: txDiff.toBN(16), data: dataDiff.toBN(16)),
        lookup: newTable[string, Index](),
        verifications: newTable[string, seq[BLSPublicKey]](),
        accounts: newTable[string, Account]()
    )

    #Add the minter account.
    result.accounts["minter"] = newAccountObj(result.db, "minter")

#Add a hash to the lookup.
func addHash*(
    lattice: Lattice,
    hash: Hash[512],
    index: Index
) {.raises: [].} =
    lattice.lookup[hash.toString()] = index

#Creates a new Account on the Lattice.
func addAccount*(
    lattice: Lattice,
    address: string
) {.raises: [].} =
    #Make sure the account doesn't already exist.
    if lattice.accounts.hasKey(address):
        return

    lattice.accounts[address] = newAccountObj(lattice.db, address)

#Gets an account.
func getAccount*(
    lattice: Lattice,
    address: string
): Account {.raises: [ValueError].} =
    #Call addAccount, which will only create an account if one doesn't exist.
    lattice.addAccount(address)

    #Return the account.
    result = lattice.accounts[address]

#Gets a Entry by its Index.
proc `[]`*(lattice: Lattice, index: Index): Entry {.raises: [ValueError].} =
    if not lattice.accounts.hasKey(index.key):
        raise newException(ValueError, "Lattice does not have an Account for that address.")
    if lattice.accounts[index.key].height <= index.nonce:
        raise newException(ValueError, "The Account for that address doesn't have a Entry for that nonce.")

    result = lattice.accounts[index.key][index.nonce]

#Gets a Entry by its hash.
proc `[]`*(lattice: Lattice, hash: string): Entry {.raises: [KeyError, ValueError].} =
    if not lattice.lookup.hasKey(hash):
        #Do not change this Exception message. It is checked for when syncing.
        raise newException(ValueError, "Lattice does not have a Entry for that hash.")

    var
        index: Index = lattice.lookup[hash]
        entries: seq[Entry] = lattice.accounts[index.key].entries[int(index.nonce)]

    for entry in entries:
        if entry.hash.toString() == hash:
            return entry

    #If there's no Entry there, that means it was deleted because a different Entry got confirmed.
    raise newException(ValueError, "That hash has been orphaned.")
