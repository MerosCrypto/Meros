#Errors lib.
import ../../lib/Errors

#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet
import ../../Wallet/Address

#Index object.
import objects/IndexObj

#Entry object and descendants.
import objects/EntryObj
import objects/SendObj
import objects/ReceiveObj
import objects/DataObj
import objects/MeritRemovalObj

#Account object.
import objects/AccountObj
export AccountObj

#Add a Entry.
proc add(
    account: Account,
    entry: Entry,
    dependent: Entry = nil
): bool {.raises: [ValueError, SodiumError].} =
    result = true

    #Verify the sender.
    if entry.sender != account.address:
        return false

    #Verify the nonce.
    if uint(account.entries.len) != entry.nonce:
        return false

    #If it's a valid minter Entry...
    if (
        (account.address == "minter") and
        (entry.descendant == EntryType.SEND)
    ):
        #Override as there's no signatures for minters.
        discard
    #Else, if it's an invalid signature...
    elif not newEdPublicKey(
        account.address.toBN().toString(256)
    ).verify(entry.hash.toString(), entry.signature):
        #Return false.
        return false

    #Add the Entry.
    account.addEntry(entry, dependent)

#Add a Send.
proc add*(
    account: Account,
    send: Send,
    difficulty: BN
): bool {.raises: [ValueError, SodiumError].} =
    #Override for minter.
    if send.sender == "minter":
        #Add the Send Entry.
        return account.add(cast[Entry](send))

    #Verify the work.
    if send.hash.toBN() < difficulty:
        return false

    #Verify the output is a valid address.
    if not Address.verify(send.output):
        return false

    #Verify the account has enough money.
    if account.balance < send.amount:
        return false

    #Add the Send.
    result = account.add(cast[Entry](send))

#Add a Receive.
proc add*(
    account: Account,
    recv: Receive,
    sendArg: Entry
): bool {.raises: [ValueError, SodiumError].} =
    #Verify the entry is a Send.
    if sendArg.descendant != EntryType.Send:
        return false

    #Cast it to a Send.
    var send: Send = cast[Send](sendArg)

    #Verify the Send's output address.
    if account.address != send.output:
        return false

    #Verify the Receive's input address.
    if recv.index.address != send.sender:
        return false

    #Verify the nonces match.
    if recv.index.nonce != send.nonce:
        return false

    #Verify it's unclaimed.
    for i in account.entries:
        if i.descendant == EntryType.Receive:
            var past: Receive = cast[Receive](i)
            if (
                (past.index.address == recv.index.address) and
                (past.index.nonce == recv.index.nonce)
            ):
                return false

    #Add the Receive.
    result = account.add(cast[Entry](recv), send)

#Add Data.
discard """
func add*(
    account: Account,
    data: Data,
    difficulty: BN
): bool {.raises: [ValueError].} =
    #Verify the work.
    if data.hash.toBN() < difficulty:
        return false

    #Add the Data.
    result = account.add(cast[Entry](data))
"""

#Add a Merit Removal.
discard """
func add*(
    account: Account,
    mr: MeritRemoval
): bool {.raises: [ValueError].} =
    result = account.add(cast[Entry](mr))
"""
