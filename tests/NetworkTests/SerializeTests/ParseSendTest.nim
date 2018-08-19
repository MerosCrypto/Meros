import ../../../src/lib/BN
import ../../../src/lib/Base

import ../../../src/Wallet/Wallet

import ../../../src/Database/Lattice/objects/NodeObj
import ../../../src/Database/Lattice/Send

import ../../../src/Network/Serialize

for i in 1 .. 20:
    echo "Testing Send Serialization/Parsing, iteration " & $i & "."

    var
        sender: Wallet = newWallet()
        receiver: Wallet = newWallet()
        send: Send = newSend(
            receiver.getAddress(),
            newBN("10000000000"),
            newBN()
        )
    send.mine("3333333333333333333333333333333333333333333333333333333333333333".toBN(16))
    discard sender.sign(send)

    var sendParsed: Send = send.serialize().parseSend()

    assert(send.getDescendant() == sendParsed.getDescendant())
    assert(send.getSender() == sendParsed.getSender())
    assert(send.getNonce() == sendParsed.getNonce())
    assert(send.getHash() == sendParsed.getHash())
    assert(send.getSignature() == sendParsed.getSignature())

    assert(send.getOutput() == sendParsed.getOutput())
    assert(send.getAmount() == sendParsed.getAmount())
    assert(send.getSHA512() == sendParsed.getSHA512())
    assert(send.getProof() == sendParsed.getProof())
