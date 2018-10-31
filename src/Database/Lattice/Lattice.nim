#Errors.
import ../../lib/Errors

#BN lib.
import BN

#Hash lib.
import ../../lib/Hash

#Merit lib.
import ../Merit/Merit

#Index object.
import objects/IndexObj
#Export the Index object.
export IndexObj

#Entry and Entry descendants.
import objects/EntryObj
import Mint
import Claim
import Send
import Receive
import Data
import MeritRemoval
#Export the Entry and Entry descendants (except Mint).
export EntryObj
export Claim
export Send
export Receive
export Data
export MeritRemoval

#Account lib.
import Account

#Lattice Objects.
import objects/LatticeObj
export LatticeObj

#String utils standard lib.
import strutils

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

        of EntryType.MeritRemoval:
            var mr: MeritRemoval = cast[MeritRemoval](entry)

            discard """
            result = account.add(
                #Data Entry.
                mr
            )
            """

    #If that didn't work, return.
    if not result:
        return

    #Else, add the Entry to the lookup table.
    lattice.addHash(
        entry.hash,
        newIndex(
            entry.sender,
            entry.nonce
        )
    )

proc mint*(
    lattice: Lattice,
    address: string,
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
        address,
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
    #Turn the hash into a string.
    var hash: string = verif.hash.toString()

    #Verify the Entry exists.
    if not lattice.lookup.hasKey(hash):
        return false
    result = true

    #Create a blank seq if there's not already a seq.
    if not lattice.verifications.hasKey(hash):
        lattice.verifications[hash] = @[]

    #Return if the Verification already exists.
    if lattice.verifications[hash].contains(verif.verifier):
        return

    #Add the Verification.
    lattice.verifications[hash].add(verif.verifier)

    #Calculate the weight.
    var weight: uint = 0
    for i in lattice.verifications[hash]:
        weight += merit.state.getBalance(i)
    #If the Entry has at least 50.1% of the weight...
    if weight > ((merit.state.live div uint(2)) + 1):
        #Get the Index of the Entry.
        var index: Index = lattice.lookup[hash]
        lattice.accounts[index.address][index.nonce].verified = true
        echo hash.toHex() & " was verified."
