#BN lib.
import BN

#Entry, Send, and Receive objects.
import EntryObj
import SendObj
import ReceiveObj

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
            #Cast it to a var.
            var recv: Receive = cast[Receive](entry)
            #Cast the matching Send.
            var send: Send = cast[Send](dependent)
            #Update the balance.
            account.balance += send.amount
        else:
            discard

#Helper getter that takes in an index.
func `[]`*(account: Account, index: uint): Entry {.raises: [ValueError].} =
    if index >= uint(account.entries.len):
        raise newException(ValueError, "Account index out of bounds.")

    result = account.entries[int(index)]
