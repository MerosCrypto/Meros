#Errors lib.
import ../../../lib/Errors

#Numerical libs.
import BN
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Merit lib.
import ../../Merit/Merit

#ParseEntry lib.
import ../../../Network/Serialize/Lattice/ParseEntry

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Index object.
import ../../common/objects/IndexObj

#Entry object.
import EntryObj

#Account object.
import AccountObj

#Tables standard library.
import tables

#Lattice master object.
type Lattice* = ref object of RootObj
    #Database.
    db*: DatabaseFunctionBox
    accountsStr: string

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
proc newLatticeObj*(
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

    #Grab the Accounts' string, if it exists.
    try:
        result.accountsStr = result.db.get("lattice_accounts")

        #Create a Account for each one in the string.
        for i in countup(0, result.accountsStr.len - 1, 60):
            #Extract the account.
            var address: string = result.accountsStr[i ..< i + 60]

            #Load the Account.
            result.accounts[address] = newAccountObj(result.db, address)
    #If it doesn't, set the Accounts' string to "",
    except:
        result.accountsStr = ""

#Add a hash to the lookup.
func addHash*(
    lattice: Lattice,
    hash: Hash[512],
    index: Index
) {.raises: [].} =
    lattice.lookup[hash.toString()] = index

#Creates a new Account on the Lattice.
proc add*(
    lattice: Lattice,
    address: string
) {.raises: [LMDBError].} =
    #Make sure the account doesn't already exist.
    if lattice.accounts.hasKey(address):
        return

    #Create the account.
    lattice.accounts[address] = newAccountObj(lattice.db, address)

    #Add the Account to the accounts string and then save it to the Database.
    lattice.accountsStr &= address
    lattice.db.put("lattice_accounts", lattice.accountsStr)

#Gets an account.
proc `[]`*(
    lattice: Lattice,
    address: string
): Account {.raises: [ValueError, LMDBError].} =
    #Call add, which will only create an account if one doesn't exist.
    lattice.add(address)

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
#We can't use a `[]` operator here because there's already Lattice[address: string].
proc getEntry*(
    lattice: Lattice,
    hash: string
): Entry {.raises: [KeyError].} =
    #Load the hash from the DB, raising a KeyError on failure.
    try:
        result = lattice.db.get("lattice_" & hash).parseEntry()
    except:
        raise newException(KeyError, "Lattice doesn't have an Entry for that hash.")
