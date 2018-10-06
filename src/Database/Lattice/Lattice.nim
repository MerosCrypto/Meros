#Errors.
import ../../lib/Errors

#BN lib.
import BN

#Merit lib.
import ../Merit/Merit

#Index object.
import objects/IndexObj
#Export the Index object.
export IndexObj

#Node and node descendants.
import objects/NodeObj
import Send
import Receive
import Data
import Verification
import MeritRemoval
#Export the Node and Node descendants.
export NodeObj
export Send
export Receive
export Data
export Verification
export MeritRemoval

#Account lib.
import Account

#Lattice Objects.
import objects/LatticeObj
export LatticeObj

#Finals lib.
import finals

#Add a Node to the Lattice.
proc add*(
    lattice: Lattice,
    merit: Merit,
    node: Node,
    mintOverride: bool = false
): bool {.raises: [ValueError, SodiumError].} =
    #Make sure only this node creates mint TXs.
    if (
        (node.sender == "minter") and
        (not mintOverride)
    ):
        return false

    #Get the Account.
    var account: Account = lattice.getAccount(node.sender)

    case node.descendant:
        of NodeType.Send:
            #Cast the node.
            var send: Send = cast[Send](node)

            #Add it.
            result = account.add(
                #Send Node.
                send,
                #Transaction Difficulty.
                lattice.difficulties.transaction
            )

        of NodeType.Receive:
            var recv: Receive = cast[Receive](node)

            result = account.add(
                #Receive Node.
                recv,
                #Supposed Send node.
                lattice[
                    newIndex(
                        recv.inputAddress,
                        recv.inputNonce
                    )
                ]
            )

        of NodeType.Data:
            var data: Data = cast[Data](node)

            discard """
            result = account.add(
                #Data Node.
                data,
                #Data Difficulty.
                lattice.difficulties.data
            )
            """

        of NodeType.Verification:
            var verif: Verification = cast[Verification](node)

            result = account.add(
                verif
            )

            #If that worked, add the Verification in the Lattice's tracker.
            if result:
                lattice.addVerification(merit, verif.verifies, verif.sender)

        of NodeType.MeritRemoval:
            var mr: MeritRemoval = cast[MeritRemoval](node)

            discard """
            result = account.add(
                #Data Node.
                mr
            )
            """

    #If that didn't work, return.
    if not result:
        return

    #Else, add the node to the lookup table.
    lattice.addHash(
        node.hash,
        newIndex(
            node.sender,
            node.nonce
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
    var height: BN = lattice.getAccount("minter").height

    #Create the Send Node.
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
        raise newException(MintError, "Couldn't add the Mint Node to the Lattice.")

    #Return the Index.
    result = newIndex("minter", height)
