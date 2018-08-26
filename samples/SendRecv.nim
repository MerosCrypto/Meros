#Numerical libs.
import lib/BN
import lib/Base

#Wallet lib.
import Wallet/Wallet

#Send/Receive nodes.
import Database/Lattice/Send
import Database/Lattice/Receive

#Serialization libs.
import Network/Serialize/SerializeSend
import Network/Serialize/SerializeReceive

var
    sender: Wallet = newWallet()   #Sender's wallet.
    receiver: Wallet = newWallet() #Receiver's wallet.
    send: Send = newSend(          #Send.
        receiver.getAddress(),
        newBN("10000000000"),
        newBN()
    )
    recv: Receive = newReceive(    #Receive.
        sender.getAddress(),
        newBN(),
        newBN("10000000000"),
        newBN()
    )

#Mine and sign the Send.
send.mine("3333333333333333333333333333333333333333333333333333333333333333".toBN(16))
discard sender.sign(send)

#Sign the Receive.
discard receiver.sign(recv)

#Print info on them. The length is better than a garbage string.
echo "The serialized Send is " & $send.serialize().len & " bytes long."
echo "The serialized Receive is " & $recv.serialize().len & " bytes long."
