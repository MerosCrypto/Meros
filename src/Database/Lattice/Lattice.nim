#Errors.
import ../../lib/Errors

#BN lib.
import BN

#Hash lib.
import ../../lib/Hash

#BLS lib.
import ../../lib/BLS

#Index object.
import ../common/objects/IndexObj
#Export the Index object.
export IndexObj

#Verifications lib.
import ../Verifications/Verifications

#Merit lib.
import ../Merit/Merit

#Entry and Entry descendants.
import objects/EntryObj
import Mint
import Claim
import Send
import Receive
import Data
#Export the Entry and Entry descendants.
export EntryObj
export Mint
export Claim
export Send
export Receive
export Data

#Account lib.
import Account

#Lattice Objects.
import objects/LatticeObj
export LatticeObj

#String utils standard lib.
import strutils

#Seq utils standard lib.
import sequtils

#Tables standard lib.
import tables

#Finals lib.
import finals

#Add a Entry to the Lattice.
proc add*(
    lattice: Lattice,
    merit: Merit,
    entry: Entry,
    mintOverride: bool = false
): bool {.raises: [ValueError, BLSError, SodiumError].} =
    #Make sure the sender is only minter when mintOverride is true.
    if (
        (entry.sender == "minter") and
        (not mintOverride)
    ):
        return false

    #Get the Account.
    var account: Account = lattice.getAccount(entry.sender)

    case entry.descendant:
        of EntryType.Mint:
            #Add the casted entry.
            result = account.add(cast[Mint](entry))

        of EntryType.Claim:
            #Cast it to a claim.
            var claim: Claim = cast[Claim](entry)

            #Add the casted entry (and the Mint it's trying to claim).
            result = account.add(
                claim,
                cast[Mint](lattice.accounts["minter"][claim.mintNonce])
            )

        of EntryType.Send:
            #Cast the Entry.
            var send: Send = cast[Send](entry)

            #Add it.
            result = account.add(
                #Send Entry.
                send,
                #Transaction Difficulty.
                lattice.difficulties.transaction
            )

        of EntryType.Receive:
            var recv: Receive = cast[Receive](entry)

            result = account.add(
                #Receive Entry.
                recv,
                #Supposed Send Entry.
                lattice[
                    recv.index
                ]
            )

        of EntryType.Data:
            var data: Data = cast[Data](entry)

            result = account.add(
                #Data Entry.
                data,
                #Data Difficulty.
                lattice.difficulties.data
            )

    #If that didn't work, return.
    if not result:
        return

    #If that wasn't a Mint, add the Entry to the lookup table.
    if entry.descendant != EntryType.Mint:
        lattice.addHash(
            entry.hash,
            newIndex(
                entry.sender,
                entry.nonce
            )
        )

proc mint*(
    lattice: Lattice,
    key: string,
    amount: BN
): uint {.raises: [
    ValueError,
    MintError,
    BLSError,
    SodiumError,
    FinalAttributeError
].} =
    #Store the height as the result.
    result = lattice.getAccount("minter").height

    #Create the Mint Entry.
    var mint: Mint = newMint(
        key,
        amount,
        result
    )

    #Add it to the Lattice.
    if not lattice.add(nil, mint, true):
        raise newException(MintError, "Couldn't add the Mint Entry to the Lattice.")

#Add a Verification to the Verifications' table.
proc verify*(
    lattice: Lattice,
    merit: Merit,
    verif: Verification,
): bool {.raises: [KeyError, ValueError].} =
    #Make sure the verifier has weight.
    if merit.state.getBalance(verif.verifier) == uint(0):
        return false

    #Turn the hash into a string.
    var hash: string = verif.hash.toString()

    #Verify the Entry exists.
    if not lattice.lookup.hasKey(hash):
        return false

    #Create a blank seq if there's not already a seq.
    if not lattice.verifications.hasKey(hash):
        lattice.verifications[hash] = @[]

    #Return if the Verification already exists.
    for verifier in lattice.verifications[hash]:
        if verifier == verif.verifier:
            return false

    result = true

    #Add the Verification.
    lattice.verifications[hash].add(verif.verifier)

    #Calculate the weight.
    var weight: uint = 0
    for i in lattice.verifications[hash]:
        weight += merit.state.getBalance(i)
    #If the Entry has at least 50.1% of the weight...
    if weight > ((merit.state.live div uint(2)) + 1):
        #Get the Index/Entry.
        var
            index: Index = lattice.lookup[hash]
            entry: Entry

        #Only keep the confirmed Entry.
        lattice.accounts[index.key].entries[int(index.nonce)].keepIf(
            proc (e: Entry): bool =
                verif.hash == e.hash
        )

        #Get said Entry.
        entry = lattice.accounts[index.key][index.nonce]

        #Set it to verified.
        entry.verified = true
        echo hash.toHex() & " was verified."

        #Update the balance now that the Entry is confirmed.
        case entry.descendant:
            #If it's a Send Entry...
            of EntryType.Send:
                #Cast it to a var.
                var send: Send = cast[Send](entry)
                #Update the balance.
                lattice.accounts[index.key].balance -= send.amount
            #If it's a Receive Entry...
            of EntryType.Receive:
                var
                    #Cast it to a var.
                    recv: Receive = cast[Receive](entry)
                    #Get the Send it's Receiving.
                    send: Send = cast[Send](lattice.accounts[recv.index.key][recv.index.nonce])
                #Update the balance.
                lattice.accounts[index.key].balance += send.amount
            of EntryType.Claim:
                var
                    #Cast it to a var.
                    claim: Claim = cast[Claim](entry)
                    #Get the Mint it's Claiming.
                    mint: Mint = cast[Mint](lattice.accounts["minter"][claim.mintNonce])
                #Update the balance.
                lattice.accounts[index.key].balance += mint.amount
            else:
                discard
