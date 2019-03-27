#BN lib.
import BN

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Entry, Mint, and Send objects.
import EntryObj
import MintObj
import SendObj

#Finals lib.
import finals

#Account object.
finalsd:
    type Account* = ref object of RootObj
        #DB.
        db: DatabaseFunctionBox

        #Chain owner.
        address* {.final.}: string
        #Account height.
        height*: uint
        #seq of the Entries (actually a seq of seqs so we can handle unconfirmed Entries).
        entries*: seq[seq[Entry]]
        #Balance of the address.
        balance*: BN

#Creates a new account object.
proc newAccountObj*(db: DatabaseFunctionBox, address: string): Account {.raises: [].} =
    result = Account(
        db: db,
        
        address: address,
        height: 0,
        entries: @[],
        balance: newBN()
    )
    result.ffinalizeAddress()

#Add a Entry to an account.
proc addEntry*(
    account: Account,
    entry: Entry
) {.raises: [ValueError].} =
    if entry.nonce < account.height:
        #Make sure we're not overwriting a verified Entry.
        if account.entries[int(entry.nonce)][0].verified:
            raise newException(ValueError, "Account has a verified Entry at this position.")

        #Make sure we're not adding it twice.
        for e in account.entries[int(entry.nonce)]:
            if e.hash == entry.hash:
                raise newException(ValueError, "Account already has this Entry.")

    #Add the Entry to the proper seq.
    if entry.nonce < account.height:
        #Add to an existing seq.
        account.entries[int(entry.nonce)].add(entry)
    elif entry.nonce == account.height:
        #Increase the account height.
        inc(account.height)
        #Create a new seq and add it there.
        account.entries.add(@[
            entry
        ])
    else:
        raise newException(ValueError, "Account has holes in its chain.")

#Helper getter that takes in an index.
func `[]`*(account: Account, index: uint): Entry {.raises: [ValueError].} =
    if index >= uint(account.entries.len):
        raise newException(ValueError, "Account index out of bounds.")

    if account.entries[int(index)].len != 1:
        raise newException(ValueError, "Conflicting Entries at that position with no verified Entry.")

    result = account.entries[int(index)][0]
