#Errors lib.
import ../../lib/Errors

#BN lib.
import ../../lib/BN

#SHA512 lib.
import ../../lib/SHA512

#Wallet libs.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize

#Node object.
import objects/NodeObj

#Receive object.
import objects/ReceiveObj
export ReceiveObj

#Create a new  node.
proc newReceive*(
    inputAddress: string,
    inputNonce: BN,
    amount: BN,
    nonce: BN
): Receive {.raises: [ResultError, ValueError, Exception].} =
    #Verify the input address.
    if (
        (not Wallet.verify(inputAddress)) and
        (inputAddress != "minter")
    ):
        raise newException(ValueError, "Receive address is not valid.")

    #Verify the input nonce.
    if inputNonce < BNNums.ZERO:
        raise newException(ValueError, "Receive input nonce is negative.")

    #Verify the amount.
    if amount < BNNums.ZERO:
        raise newException(ValueError, "Receive amount is negative.")

    #Verify the nonce.
    if nonce < BNNums.ZERO:
        raise newException(ValueError, "Receive nonce is negative.")

    #Craft the result.
    result = newReceiveObj(
        inputAddress,
        inputNonce,
        amount
    )

    #Set the nonce.
    if not result.setNonce(nonce):
        raise newException(ResultError, "Setting the node's nonce failed.")

    #Set the hash.
    if result.setHash(SHA512(result.serialize())) == false:
        raise newException(ResultError, "Couldn't set the node hash.")

#Sign a TX.
proc sign*(wallet: Wallet, recv: Receive): bool {.raises: [ValueError].} =
    result = true

    #Set the sender behind the node.
    if not recv.setSender(wallet.getAddress()):
        return false

    #Sign the hash of the Receive.
    if not recv.setSignature(wallet.sign(recv.getHash())):
        return false
