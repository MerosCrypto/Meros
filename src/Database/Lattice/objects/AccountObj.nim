#BN lib.
import BN

#Entry, Mint, and Send objects.
import EntryObj
import MintObj
import SendObj

#Finals lib.
import finals

#Account object.
finalsd:
    type Account* = ref object of RootObj
        #Chain owner.
        address* {.final.}: string
        #Account height. BN for compatibility.
        height*: uint
        #seq of the TXs.
        entries*: seq[Entry]
        #Balance of the address.
        balance*: BN

#Creates a new account object.
func newAccountObj*(address: string): Account {.raises: [].} =
    Account(
        address: address,
        height: 0,
        entries: @[],
        balance: newBN()
    )

#Add a Entry to an account.
proc addEntry*(
    account: Account,
    entry: Entry,
    dependent: Entry
) {.raises: [].} =
    #Increase the account height and add the Entry.
    inc(account.height)
    account.entries.add(entry)

    case entry.descendant:
        #If it's a Send Entry...
        of EntryType.Send:
            #Cast it to a var.
            var send: Send = cast[Send](entry)
            #Update the balance.
            account.balance -= send.amount
        #If it's a Receive Entry...
        of EntryType.Receive:
            #Cast the dependent to a Send.
            var send: Send = cast[Send](dependent)
            #Update the balance.
            account.balance += send.amount
        of EntryType.Claim:
            #Cast the dependent to a Mint.
            var mint: Mint = cast[Mint](dependent)
            #Update the balance.
            account.balance += mint.amount
        else:
            discard

#Helper getter that takes in an index.
func `[]`*(account: Account, index: uint): Entry {.raises: [ValueError].} =
    if index >= uint(account.entries.len):
        raise newException(ValueError, "Account index out of bounds.")

    result = account.entries[int(index)]
