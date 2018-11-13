#Errors lib.
import ../../../lib/Errors

#Numerical libs.
import BN
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#Merit lib.
import ../../Merit/Merit

#Index object.
import IndexObj

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

    #Unarchived Verifications.
    unarchived*: seq[MemoryVerification]

    #State of the Verifications. null is unset. 0 is unarchived. 1 is archived.
    archived*: TableRef[string, int]

    #Accounts (address -> account).
    accounts*: TableRef[
        string,
        Account
    ]

#Lattice constructor
func newLattice*(
    txDiff: string,
    dataDiff: string
): Lattice {.raises: [ValueError].} =
    #Create the object.
    result = Lattice(
        difficulties: (transaction: txDiff.toBN(16), data: dataDiff.toBN(16)),
        lookup: newTable[string, Index](),
        verifications: newTable[string, seq[BLSPublicKey]](),
        unarchived: @[],
        archived: newTable[string, int](),
        accounts: newTable[string, Account]()
    )

    #Add the minter account.
    result.accounts["minter"] = newAccountObj("minter")

#Add a hash to the lookup.
func addHash*(
    lattice: Lattice,
    hash: Hash[512],
    index: Index
) {.raises: [].} =
    lattice.lookup[hash.toString()] = index

#Unarchived Verification.
func unarchive*(
    lattice: Lattice,
    verif: MemoryVerification
) {.raises: [KeyError].} =
    #Make sure the Verif is new.
    if lattice.archived.hasKey(verif.hash.toString() & verif.verifier.toString()):
        return

    #Add to unarchived.
    lattice.unarchived.add(verif)

    #Set it as unarchived.
    lattice.archived[verif.hash.toString() & verif.verifier.toString()] = 0

#Archive a Verification.
func archive*(
    lattice: Lattice,
    verif: MemoryVerification
) {.raises: [KeyError].} =
    #Make sure the Verif isn't already archived.
    if lattice.archived[verif.hash.toString() & verif.verifier.toString()] == 1:
        return

    #Remove it from unarchived.
    for i in 0 ..< lattice.unarchived.len:
        if (
            (verif.hash == lattice.unarchived[i].hash) and
            (verif.verifier == lattice.unarchived[i].verifier)
        ):
            lattice.unarchived.delete(i)
            break

    #Set it as archived.
    lattice.archived[verif.hash.toString() & verif.verifier.toString()] = 1

#Creates a new Account on the Lattice.
func addAccount*(
    lattice: Lattice,
    address: string
) {.raises: [].} =
    #Make sure the account doesn't already exist.
    if lattice.accounts.hasKey(address):
        return

    lattice.accounts[address] = newAccountObj(address)

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
    if not lattice.accounts.hasKey(index.address):
        raise newException(ValueError, "Lattice does not have an Account for that address.")
    if lattice.accounts[index.address].height <= index.nonce:
        raise newException(ValueError, "The Account for that address doesn't have a Entry for that nonce.")

    result = lattice.accounts[index.address][index.nonce]

#Gets a Entry by its hash.
proc `[]`*(lattice: Lattice, hash: string): Entry {.raises: [KeyError, ValueError].} =
    if not lattice.lookup.hasKey(hash):
        raise newException(ValueError, "Lattice does not have a Entry for that hash.")

    result = lattice[lattice.lookup[hash]]
