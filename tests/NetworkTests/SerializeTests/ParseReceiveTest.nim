import ../../../src/lib/BN
import ../../../src/lib/Base

import ../../../src/Wallet/Wallet

import ../../../src/Database/Lattice/objects/NodeObj
import ../../../src/Database/Lattice/Send
import ../../../src/Database/Lattice/Receive

import ../../../src/Network/Serialize

for i in 1 .. 20:
    echo "Testing Receive Serialization/Parsing, iteration " & $i & "."

    var
        sender: Wallet = newWallet()
        receiver: Wallet = newWallet()
        send: Send
        recv: Receive

    send = newSend(
        receiver.getAddress(),
        newBN("10000000000"),
        newBN()
    )
    send.mine("3333333333333333333333333333333333333333333333333333333333333333".toBN(16))
    discard sender.sign(send)

    recv = newReceive(
        sender.getAddress(),
        newBN(),
        newBN("10000000000"),
        newBN()
    )
    discard receiver.sign(recv)

    var recvParsed: Receive = recv.serialize().parseReceive()

    assert(
        recv.getDescendant() == recvParsed.getDescendant(),
        "Descendant:\r\n" & $recv.getDescendant() & "\r\n\r\n" & $recvParsed.getDescendant()
    )
    assert(
        recv.getSender == recvParsed.getSender(),
        "Sender:\r\n" & recv.getSender() & "\r\n\r\n" & recvParsed.getSender()
    )
    assert(
        recv.getNonce() == recvParsed.getNonce(),
        "Nonce:\r\n" & $recv.getNonce() & "\r\n\r\n" & $recvParsed.getNonce()
    )
    assert(
        recv.getHash() == recvParsed.getHash(),
        "Hash:\r\n" & recv.getHash() & "\r\n\r\n" & recvParsed.getHash()
    )
    assert(
        recv.getSignature() == recvParsed.getSignature(),
        "Signature:\r\n" & recv.getSignature() & "\r\n\r\n" & recvParsed.getSignature()
    )

    assert(
        recv.getInputAddress() == recvParsed.getInputAddress(),
        "Input Address:\r\n" & recv.getInputAddress() & "\r\n\r\n" & recvParsed.getInputAddress()
    )
    assert(
        recv.getInputNonce() == recvParsed.getInputNonce(),
        "Input Nonce:\r\n" & $recv.getInputNonce() & "\r\n\r\n" & $recvParsed.getInputNonce()
    )
    assert(
        recv.getAmount() == recvParsed.getAmount(),
        "Amount:\r\n" & $recv.getAmount() & "\r\n\r\n" & $recvParsed.getAmount()
    )
