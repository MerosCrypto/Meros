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
    if not newPublicKey(
        account.getAddress().toBN().toString(16)
    ).verify(node.getHash(), node.getSignature()):
        return false

    #Add the node.
    account.addNode(node)

#Add a Send.
proc add*(account: Account, send: Send, difficulty: BN): bool {.raises: [ValueError, Exception].} =
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
proc add*(account: Account, recv: Receive, send: Node): bool {.raises: [ValueError, Exception].} =
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
