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
import Send
import Receive
import Data
import MeritRemoval
#Export the Entry and Entry descendants.
export EntryObj
export Send
export Receive
export Data
export MeritRemoval

#Account lib.
import Account

#Lattice Objects.
import objects/LatticeObj
export LatticeObj

#Finals lib.
import finals

#Add a Entry to the Lattice.
proc add*(
    lattice: Lattice,
    merit: Merit,
    entry: Entry,
    mintOverride: bool = false
): bool {.raises: [ValueError, SodiumError].} =
    #Make sure the sender is only minter when mintOverride is true.
    if (
        (entry.sender == "minter") and
        (not mintOverride)
    ):
        return false

    #Get the Account.
    var account: Account = lattice.getAccount(entry.sender)

    case entry.descendant:
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

            discard """
            result = account.add(
                #Data Entry.
                data,
                #Data Difficulty.
                lattice.difficulties.data
            )
            """

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
): Index {.raises: [
    ValueError,
    ArgonError,
    SodiumError,
    MintError,
    FinalAttributeError
].} =
    #Get the Height in a new var that won't update.
    var height: uint = lattice.getAccount("minter").height

    #Create the Send Entry.
    var send: Send = newSend(
        address,
        amount,
        height
    )
    #Mine it.
    send.mine(newBN())

    #Set the sender.
    send.sender = "minter"

    #Add it to the Lattice.
    if not lattice.add(nil, send, true):
        raise newException(MintError, "Couldn't add the Mint Entry to the Lattice.")

    #Return the Index.
    result = newIndex("minter", height)
