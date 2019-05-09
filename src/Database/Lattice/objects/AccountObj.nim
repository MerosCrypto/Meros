#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet libs.
import ../../../Wallet/Address
import ../../../Wallet/Wallet

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#LatticeIndex object.
import ../../common/objects/LatticeIndexObj

#Entry object.
import EntryObj

#Send object.
import SendObj

#Serialize/Parse Entry functions.
import ../../../Network/Serialize/Lattice/SerializeEntry
import ../../../Network/Serialize/Lattice/ParseEntry

#Finals lib.
import finals

#Tables standard lib.
import tables

#Account object.
finalsd:
    type Account* = ref object
        #DB.
        db: DatabaseFunctionBox
        #Table of hashes we loaded from the DB -> LatticeIndex.
        lookup*: TableRef[string, LatticeIndex]

        #Chain owner.
        address* {.final.}: string
        #Account height.
        height*: Natural
        #Nonce of the highest Entry popped out of Epochs.
        confirmed*: Natural
        #seq of the Entries (actually a seq of seqs so we can handle unconfirmed Entries).
        entries*: seq[seq[Entry]]
        #Balance of the address.
        balance*: uint64

        #Amount of money spent in pending Entries.
        #https://github.com/MerosCrypto/Meros/issues/42
        potentialDebt*: uint64

#Creates a new account object.
proc newAccountObj*(
    db: DatabaseFunctionBox,
    address: string
): Account {.forceCheck: [
    AddressError
].} =
    #Verify the address.
    if (address != "minter") and (not address.isValid()):
        raise newException(AddressError, "Invalid Address passed to `newAccountObj`.")

    result = Account(
        db: db,

        address: address,
        height: 0,
        confirmed: 0,
        entries: @[],
        balance: 0
    )
    result.ffinalizeAddress()

    #Load the heights/balance.
    try:
        result.height = result.db.get("lattice_" & result.address).fromBinary()
        result.confirmed = result.db.get("lattice_" & result.address & "_confirmed").fromBinary()
        result.balance = uint64(result.db.get("lattice_" & result.address & "_balance").fromBinary())
    #The Account must not exist.
    except DBReadError:
        try:
            result.db.put("lattice_" & result.address, 0.toBinary())
            result.db.put("lattice_" & result.address & "_confirmed", 0.toBinary())
            result.db.put("lattice_" & result.address & "_balance", "")
        except DBWriteError as e:
            doAssert(false, "Couldn't save a new Account to the Database: " & e.msg)

    #Create a lookup table for storing hashes.
    result.lookup = newTable[string, LatticeIndex]()

    #Load every Entry still in the Epochs (or yet to enter an Epoch).
    result.entries = newSeq[seq[Entry]](result.height - result.confirmed)
    for i in result.confirmed ..< result.height:
        #Max debt for this unconfirmed Entry.
        var maxDebt: uint64 = 0

        #Load the potential hashes.
        var hashes: string
        try:
            hashes = result.db.get("lattice_" & result.address & "_" & i.toBinary())
        except DBReadError as e:
            doAssert(false, "Couldn't load the unconfirmed hashes from the Database: " & e.msg)

        #Load the Entries.
        result.entries[i - result.confirmed] = newSeq[Entry](hashes.len div 48)
        for h in countup(0, hashes.len - 1, 48):
            result.lookup[hashes[h ..< h + 48]] = newLatticeIndex(result.address, i)

            var loadedEntry: Entry
            try:
                loadedEntry = result.db.get("lattice_" & hashes[h ..< h + 48]).parseEntry()
            except ValueError as e:
                doAssert(false, "Couldn't parse an unconfirmed Entry, which was successfully retrieved from the Database, due to a ValueError: " & e.msg)
            except ArgonError as e:
                doAssert(false, "Couldn't parse an unconfirmed Entry, which was successfully retrieved from the Database, due to a ArgonError: " & e.msg)
            except BLSError as e:
                doAssert(false, "Couldn't parse an unconfirmed Entry, which was successfully retrieved from the Database, due to a BLSError: " & e.msg)
            except EdPublicKeyError as e:
                doAssert(false, "Couldn't parse an unconfirmed Entry, which was successfully retrieved from the Database, due to a EdPublicKeyError: " & e.msg)
            except DBReadError as e:
                doAssert(false, "Couldn't load an unconfirmed Entry from the Database: " & e.msg)
            result.entries[i - result.confirmed][h div 48] = loadedEntry

            if loadedEntry.descendant == EntryType.Send:
                if cast[Send](loadedEntry).amount > maxDebt:
                    maxDebt = cast[Send](loadedEntry).amount

            result.potentialDebt += maxDebt

#Add a Entry to an account.
proc add*(
    account: Account,
    entry: Entry
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    EdPublicKeyError,
    DataExists
].} =
    #Check the Signature, if it's not a mint.
    if entry.descendant == EntryType.Mint:
        discard
    else:
        var pubKey: EdPublicKey
        try:
            pubKey = newEdPublicKey(
                Address.toPublicKey(account.address)
            )
        except AddressError:
            doAssert(false, "Created an account with an invalid address.")
        except EdPublicKeyError as e:
            fcRaise e

        if not pubKey.verify(entry.hash.toString(), entry.signature):
            raise newException(ValueError, "Failed to verify the Entry's signature.")

    var
        #Correct for the Entries no longer in RAM.
        i: int = entry.nonce - account.confirmed
        #Variable for the max potential debt.
        maxDebt: uint64 = 0

    #If this is a Send, set the initial max debt value to it.
    if entry.descendant == EntryType.Send:
        maxDebt = cast[Send](entry).amount

    if entry.nonce < account.height:
        #Make sure we're not overwriting something outside of the cache.
        if entry.nonce < account.confirmed:
            raise newException(IndexError, "Account has a verified Entry at this position.")

        #Make sure we're not adding it twice (and calculate the max potential debt).
        for e in account.entries[i]:
            if e.descendant == EntryType.Send:
                if cast[Send](e).amount > maxDebt:
                    maxDebt = cast[Send](e).amount

            if e.hash == entry.hash:
                raise newException(DataExists, "Account already has this Entry.")

        #Add the Entry to the proper seq.
        account.entries[i].add(entry)
    #Else, if it's a new index.
    elif entry.nonce == account.height:
        #Increase the account height.
        inc(account.height)
        #Create a new seq and add it there.
        account.entries.add(@[
            entry
        ])

        #Save the new height to the DB.
        try:
            account.db.put("lattice_" & account.address, account.height.toBinary())
        except DBWriteError as e:
            doAssert(false, "Couldn't save an Account's new height to the Database: " & e.msg)
    else:
        raise newException(GapError, "Account has holes in its chain.")

    #Update the Account's pending potential debt.
    account.potentialDebt += maxDebt

    #Save the Entry to the DB.
    try:
        account.db.put("lattice_" & entry.hash.toString(), char(entry.descendant) & entry.serialize())
    except DBWriteError as e:
        doAssert(false, "Couldn't save an Entry to the Database: " & e.msg)

    #Save the list of entries at this index to the DB .
    var hashes: string
    for e in account.entries[i]:
        hashes &= e.hash.toString()
    try:
        account.db.put("lattice_" & account.address & "_" & entry.nonce.toBinary(), hashes)
    except DBWriteError as e:
        doAssert(false, "Couldn't save the list of hashes for an index to the Database: " & e.msg)

#Getter.
proc `[]`*(
    account: Account,
    index: int
): Entry {.forceCheck: [
    ValueError,
    IndexError
].} =
    #Check the index is in bounds.
    if index >= account.height:
        raise newException(IndexError, "Account index out of bounds.")

    #If it's in the database...
    if index < account.confirmed:
        try:
            #Grab it.
            result = account.db.get(
                "lattice_" &
                account.db.get("lattice_" & account.address & "_" & index.toBinary())
            ).parseEntry()
        except ValueError as e:
            doAssert(false, "Couldn't parse an confirmed Entry, which was successfully retrieved from the Database, due to a ValueError: " & e.msg)
        except ArgonError as e:
            doAssert(false, "Couldn't parse an confirmed Entry, which was successfully retrieved from the Database, due to a ArgonError: " & e.msg)
        except BLSError as e:
            doAssert(false, "Couldn't parse an confirmed Entry, which was successfully retrieved from the Database, due to a BLSError: " & e.msg)
        except EdPublicKeyError as e:
            doAssert(false, "Couldn't parse an confirmed Entry, which was successfully retrieved from the Database, due to a EdPublicKeyError: " & e.msg)
        except DBReadError as e:
            doAssert(false, "Couldn't load a Entry we were asked for from the Database: " & e.msg)
        try:
            #Mark it as verified.
            result.verified = true
        except FinalAttributeError as e:
            doAssert(false, "Set a final attribute twice when creating a Mint: " & e.msg)
        #Return it.
        return

    #Else, check if there is a singular Entry we can return from memory.
    var i: int = index - account.confirmed
    if account.entries[i].len != 1:
        for e in account.entries[i]:
            if e.verified:
                return e
        raise newException(ValueError, "Conflicting Entries at that position with no verified Entry.")
    result = account.entries[i][0]

#Getter used exlusively by Lattice[hash]. That getter confirms the entry is in RAM.
proc `[]`*(
    account: Account,
    index: int,
    hash: Hash[384]
): Entry {.forceCheck: [].} =
    var i: int = index - account.confirmed
    if i >= account.entries.len:
        doAssert(false, "Entry we tried to retrieve by hash wasn't actually in RAM, as checked by the i value.")

    for entry in account.entries[i]:
        for e in account.entries[i]:
            if entry.hash == hash:
                return entry
    doAssert(false, "Entry we tried to retrieve by hash wasn't actually in RAM, as checked by the hash.")
