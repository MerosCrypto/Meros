#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#Hashing libraries.
import ../../lib/SHA512
import ../../lib/Argon

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
proc add(account: Account, node: Node): bool {.raises: [ValueError, Exception].} =
    result = true

    #Verify the sender.
    if node.getSender() != account.getAddress():
        return false

    #Verify the nonce.
    if newBN(account.getNodes().len) != node.getNonce():
        return false

    #Verify the signature.
    if (
        (account.getAddress() != "minter") and
        (
            not newPublicKey(
                account.getAddress().toBN().toString(16)
            ).verify(node.getHash(), node.getSignature())
        )
    ):
        return false

    #Add the node.
    account.addNode(node)

#Add a Send.
proc add*(account: Account, send: Send, difficulty: BN): bool {.raises: [ValueError, Exception].} =
    #Override for minter.
    if send.getSender() == "minter":
        #Add the Send node.
        return account.add(cast[Node](send))

    #Verify the work.
    if send.getHash().toBN(16) < difficulty:
        return false

    #Verify the output is a valid address.
    if not Address.verify(send.getOutput()):
        return false

    #Verify the account has enough money.
    if account.getBalance() < send.getAmount():
        return false

    #Add the Send.
    result = account.add(cast[Node](send))

#Add a Receive.
proc add*(account: Account, recv: Receive, sendArg: Node): bool {.raises: [ValueError, Exception].} =
    #Verify the node is a Send.
    if sendArg.descendant != NodeSend:
        return false

    #Cast it to a Send.
    var send: Send = cast[Send](sendArg)

    #Verify the Send's output address.
    if account.getAddress() != send.getOutput():
        return false

    #Verify the Receive's input address.
    if recv.getInputAddress() != send.getSender():
        return false

    #Verify the nonces match.
    if recv.getInputNonce() != send.getNonce():
        return false

    #Verify the balances match.
    if recv.getAmount() != send.getAmount():
        return false

    #Verify it's unclaimed.
    for i in account.getNodes():
        if i.descendant == NodeReceive:
            var past: Receive = cast[Receive](i)
            if (
                (past.getInputAddress() == recv.getInputAddress()) and
                (past.getInputNonce() == recv.getInputNonce())
            ):
                return false

    #Add the Receive.
    result = account.add(cast[Node](recv))

#Add Data.
proc add*(account: Account, data: Data, difficulty: BN): bool {.raises: [ValueError, Exception].} =
    #Verify the work.
    if data.getHash().toBN(16) < difficulty:
        return false

    #Add the data.
    result = account.add(cast[Node](data))

#Add a Verification.
proc add*(account: Account, verif: Verification): bool {.raises: [ValueError, Exception].} =
    result = account.add(cast[Node](verif))

#Add a Merit Removal.
proc add*(account: Account, mr: MeritRemoval): bool {.raises: [ValueError, Exception].} =
    result = account.add(cast[Node](mr))
