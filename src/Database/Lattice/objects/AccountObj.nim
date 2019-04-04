#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Numerical libs.
import BN
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Serialize/Parse Entry functions.
import ../../../Network/Serialize/Lattice/SerializeEntry
import ../../../Network/Serialize/Lattice/ParseEntry

#Index object.
import ../../common/objects/IndexObj

#Entry, Mint, and Send objects.
import EntryObj
import MintObj
import SendObj

#Finals lib.
import finals

#Tables standard lib.
import tables

#Account object.
finalsd:
    type Account* = ref object of RootObj
        #DB.
        db: DatabaseFunctionBox
        #Table of hashes we loaded from the DB -> Index.
        lookup*: TableRef[string, Index]

        #Chain owner.
        address* {.final.}: string
        #Account height.
        height*: uint
        #Nonce of the highest confirmed Entry (where everything before it is also confirmed).
        confirmed*: uint
        #seq of the Entries (actually a seq of seqs so we can handle unconfirmed Entries).
        entries*: seq[seq[Entry]]
        #Balance of the address.
        balance*: BN

#Creates a new account object.
proc newAccountObj*(db: DatabaseFunctionBox, address: string, load: bool = false): Account {.raises: [].} =
    result = Account(
        db: db,

        address: address,
        height: 0,
        confirmed: 0,
        entries: @[],
        balance: newBN()
    )
    result.ffinalizeAddress()

    #If we're supposed to load this Account from the DB...
    if load:
        try:
            #Load the heights/balance.
            result.height = uint(result.db.get("lattice_" & result.address).fromBinary())
            result.confirmed = uint(result.db.get("lattice_" & result.address & "_confirmed").fromBinary())
            result.balance = result.db.get("lattice_" & result.address & "_balance").toBN(256)

            #Create a lookup table for storing hashes.
            result.lookup = newTable[string, Index]()

            #Load every unconfirmed Entry.
            result.entries = newSeq[seq[Entry]](result.height - result.confirmed)
            for i in result.confirmed ..< result.height:
                var hashes: string = result.db.get("lattice_" & result.address & "_" & i.toBinary())
                result.entries[int(i - result.confirmed)] = newSeq[Entry](hashes.len div 64)
                for h in countup(0, hashes.len - 1, 64):
                    result.lookup[hashes[h ..< h + 64]] = newIndex(result.address, i)
                    result.entries[int(i - result.confirmed)][h div 64] = result.db.get("lattice_" & hashes[h ..< h + 64]).parseEntry()
        #If we're not in the DB, add ourselves.
        except:
            if address != "minter":
                echo getCurrentExceptionMsg()
    #If this account ia new, provide default values.
    else:
        try:
            result.db.put("lattice_" & result.address, 0.toBinary())
            result.db.put("lattice_" & result.address & "_confirmed", 0.toBinary())
            result.db.put("lattice_" & result.address & "_balance", newBN().toString(256))
        except:
            discard

#Add a Entry to an account.
proc addEntry*(
    account: Account,
    entry: Entry
) {.raises: [ValueError, LMDBError].} =
    #Correct for the Entries no longer in RAM.
    var
        offset: int = int(account.height) - account.entries.len
        i: int = int(entry.nonce) - offset

    if entry.nonce < account.height:
        #Make sure we're not overwriting something out of the cache.
        if entry.nonce < account.confirmed:
            raise newException(ValueError, "Account has a verified Entry at this position.")
        if account.entries[i][0].verified:
            raise newException(ValueError, "Account has a verified Entry at this position.")

        #Make sure we're not adding it twice.
        for e in account.entries[i]:
            if e.hash == entry.hash:
                raise newException(ValueError, "Account already has this Entry.")

    #Add the Entry to the proper seq.
    if entry.nonce < account.height:
        #Add to an existing seq.
        account.entries[i].add(entry)
    elif entry.nonce == account.height:
        #Increase the account height.
        inc(account.height)
        #Create a new seq and add it there.
        account.entries.add(@[
            entry
        ])
        #Save the new height to the DB.
        account.db.put("lattice_" & account.address, account.height.toBinary())
    else:
        raise newException(ValueError, "Account has holes in its chain.")

    #Save the Entry to the DB.
    account.db.put("lattice_" & entry.hash.toString(), char(entry.descendant) & entry.serialize())

    #Save the list of entries at this index to the DB .
    var hashes: string
    for e in account.entries[i]:
        hashes &= e.hash.toString()
    account.db.put("lattice_" & account.address & "_" & entry.nonce.toBinary(), hashes)

#Helper getter that takes in an index.
proc `[]`*(account: Account, index: uint): Entry {.raises: [ValueError].} =
    #Check the index is in bounds.
    if index >= uint(account.height):
        raise newException(ValueError, "Account index out of bounds.")

    #If it's in the database...
    if index < account.confirmed:
        try:
            #Grab it.
            result = account.db.get(
                "lattice_" &
                account.db.get("lattice_" & account.address & "_" & index.toBinary())
            ).parseEntry()
            #Mark it as verified.
            result.verified = true
            #Return it.
            return
        except:
            raise newException(ValueError, getCurrentExceptionMsg())

    #Else, check if there is a singular Entry we can return from memory.
    var
        offset: int = int(account.height) - account.entries.len
        i: int = int(index) - offset
    if account.entries[i].len != 1:
        raise newException(ValueError, "Conflicting Entries at that position with no verified Entry.")
    result = account.entries[i][0]
