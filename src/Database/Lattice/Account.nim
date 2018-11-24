#Errors lib.
import ../../lib/Errors

#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#BLS lib.
import ../../lib/BLS

#Wallet libs.
import ../../Wallet/Wallet
import ../../Wallet/Address

#Index object.
import objects/IndexObj

#Entry object and descendants.
import objects/EntryObj
import objects/MintObj
import objects/ClaimObj
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
    entry: Entry
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
        (entry.descendant == EntryType.Mint)
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
    account.addEntry(entry)

#Add a Mint.
proc add*(
    account: Account,
    mint: Mint
): bool {.raises: [ValueError, SodiumError].} =
    account.add(cast[Entry](mint))

#Add a Claim.
proc add*(
    account: Account,
    claim: Claim,
    mint: Mint
): bool {.raises: [ValueError, BLSError, SodiumError].} =
    #Verify the BLS signature is for this mint and this person.
    try:
        claim.bls.setAggregationInfo(
            newBLSAggregationInfo(
                newBLSPublicKey(mint.output),
                $mint.nonce & "." & account.address
            )
        )
    except:
        raise newException(BLSError, "Couldn't create a Public Key from the Mint/add the aggregation info to the Claim.")
    if not claim.bls.verify():
        return false

    #Verify it's unclaimed.
    for i in account.entries:
        if i[0].descendant == EntryType.Claim:
            var past: Claim = cast[Claim](i)
            if claim.mintNonce == past.mintNonce:
                return false

    #Add the Claim.
    result = account.add(cast[Entry](claim))

#Add a Send.
proc add*(
    account: Account,
    send: Send,
    difficulty: BN
): bool {.raises: [ValueError, SodiumError].} =
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
    for entries in account.entries:
        if entries[0].descendant == EntryType.Receive:
            var past: Receive = cast[Receive](entries[0])
            if (
                (past.index.address == recv.index.address) and
                (past.index.nonce == recv.index.nonce)
            ):
                return false

    #Add the Receive.
    result = account.add(cast[Entry](recv))

#Add Data.
proc add*(
    account: Account,
    data: Data,
    difficulty: BN
): bool {.raises: [ValueError, SodiumError].} =
    #Verify the work.
    if data.hash.toBN() < difficulty:
        return false

    #Add the Data.
    result = account.add(cast[Entry](data))

#Add a Merit Removal.
discard """
func add*(
    account: Account,
    mr: MeritRemoval
): bool {.raises: [ValueError].} =
    result = account.add(cast[Entry](mr))
"""
