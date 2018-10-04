#Errors lib.
import ../../lib/Errors

#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Wallet libraries.
import ../../Wallet/Wallet
import ../../Wallet/Address

#Node object and descendants.
import objects/NodeObj
import objects/SendObj
import objects/ReceiveObj
import objects/DataObj
import objects/VerificationObj
import objects/MeritRemovalObj

#Account object.
import objects/AccountObj
export AccountObj

#Add a node.
proc add(
    account: Account,
    node: Node,
    dependent: Node = nil
): bool {.raises: [ValueError, SodiumError].} =
    result = true

    #Verify the sender.
    if node.sender != account.address:
        return false

    #Verify the nonce.
    if newBN(account.nodes.len) != node.nonce:
        return false

    #If it's a valid minter node...
    if (
        (account.address == "minter") and
        (node.descendant == NodeType.SEND)
    ):
        #Override as there's no signatures for minters.
        discard
    #Else, if it's an invalid signature...
    elif not newPublicKey(
        account.address.toBN().toString(256)
    ).verify(node.hash.toString(), node.signature):
        #Return false.
        return false

    #Add the node.
    account.addNode(node, dependent)

#Add a Send.
proc add*(
    account: Account,
    send: Send,
    difficulty: BN
): bool {.raises: [ValueError, SodiumError].} =
    #Override for minter.
    if send.sender == "minter":
        #Add the Send node.
        return account.add(cast[Node](send))

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
    result = account.add(cast[Node](send))

#Add a Receive.
proc add*(
    account: Account,
    recv: Receive,
    sendArg: Node
): bool {.raises: [ValueError, SodiumError].} =
    #Verify the node is a Send.
    if sendArg.descendant != NodeType.Send:
        return false

    #Cast it to a Send.
    var send: Send = cast[Send](sendArg)

    #Verify the Send's output address.
    if account.address != send.output:
        return false

    #Verify the Receive's input address.
    if recv.inputAddress != send.sender:
        return false

    #Verify the nonces match.
    if recv.inputNonce != send.nonce:
        return false

    #Verify it's unclaimed.
    for i in account.nodes:
        if i.descendant == NodeType.Receive:
            var past: Receive = cast[Receive](i)
            if (
                (past.inputAddress == recv.inputAddress) and
                (past.inputNonce == recv.inputNonce)
            ):
                return false

    #Add the Receive.
    result = account.add(cast[Node](recv), send)

#Add Data.
discard """
proc add*(
    account: Account,
    data: Data,
    difficulty: BN
): bool {.raises: [ValueError].} =
    #Verify the work.
    if data.hash.toBN() < difficulty:
        return false

    #Add the Data.
    result = account.add(cast[Node](data))
"""

#Add a Verification.
proc add*(
    account: Account,
    verif: Verification
): bool {.raises: [ValueError, SodiumError].} =
    #Add the Verification.
    result = account.add(cast[Node](verif))

#Add a Merit Removal.
discard """
proc add*(
    account: Account,
    mr: MeritRemoval
): bool {.raises: [ValueError].} =
    result = account.add(cast[Node](mr))
"""
