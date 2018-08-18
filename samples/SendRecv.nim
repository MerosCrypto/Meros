import lib/BN
import lib/Base

import Wallet/Wallet

import Database/Lattice/Send
import Database/Lattice/Receive

import Network/Serialize

var
    sender: Wallet = newWallet()
    receiver: Wallet = newWallet()
    send: Send = newSend(
        receiver.getAddress(),
        newBN("10000000000"),
        newBN()
    )
    recv: Receive = newReceive(
        sender.getAddress(),
        newBN(),
        newBN("10000000000"),
        newBN()
    )

send.mine("3333333333333333333333333333333333333333333333333333333333333333".toBN(16))
discard sender.sign(send)
discard receiver.sign(recv)

echo send.serialize().len
echo recv.serialize().len
