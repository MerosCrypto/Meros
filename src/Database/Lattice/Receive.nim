#BN lib.
import BN

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/SerializeReceive

#Index object.
import objects/LatticeObjs

#Node object.
import objects/NodeObj

#Receive object.
import objects/ReceiveObj
export ReceiveObj

#Finals lib.
import finals

#Create a new Receive node.
proc newReceive*(
    inputAddress: string,
    inputNonce: BN,
    nonce: BN
): Receive {.raises: [ValueError, FinalAttributeError].} =
    #Verify the input address.
    if (
        (not Wallet.verify(inputAddress)) and
        (inputAddress != "minter")
    ):
        raise newException(ValueError, "Receive address is not valid.")

    #Verify the input nonce.
    if inputNonce < BNNums.ZERO:
        raise newException(ValueError, "Receive input nonce is negative.")

    #Verify the nonce.
    if nonce < BNNums.ZERO:
        raise newException(ValueError, "Receive nonce is negative.")

    #Craft the result.
    result = newReceiveObj(
        inputAddress,
        inputNonce
    )

    #Set the nonce.
    result.nonce = nonce

    #Set the hash.
    result.hash = SHA512(result.serialize())

#Create a new Receive node.
proc newReceive*(index: Index, nonce: BN): Receive {.raises: [ValueError, FinalAttributeError].} =
    newReceive(
        index.address,
        index.nonce,
        nonce
    )

#Sign a TX.
proc sign*(wallet: Wallet, recv: Receive) {.raises: [ValueError, FinalAttributeError].} =
    #Set the sender behind the node.
    recv.sender = wallet.address
    #Sign the hash of the Receive.
    recv.signature = wallet.sign($recv.hash)
