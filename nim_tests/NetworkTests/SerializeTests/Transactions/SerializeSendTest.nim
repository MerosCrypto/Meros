#Serialize Send Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Wallet libs.
import ../../../../src/Wallet/Wallet

#Send lib.
import ../../../../src/Database/Transactions/Send

#Serialize libs.
import ../../../../src/Network/Serialize/Transactions/SerializeSend
import ../../../../src/Network/Serialize/Transactions/ParseSend

#Compare Transactions lib.
import ../../../DatabaseTests/TransactionsTests/CompareTransactions

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    var
        #Hash used to create an input.
        hash: Hash[384]
        #Inputs.
        inputs: seq[SendInput]
        #Outputs.
        outputs: seq[SendOutput]
        #Send.
        send: Send
        #Reloaded Send.
        reloaded: Send
        #Wallet.
        wallet: Wallet = newWallet("")

    #Test 255 serializations.
    for s in 0 .. 255:
        #Create the inputs.
        inputs = newSeq[SendInput](rand(254) + 1)
        for i in 0 ..< inputs.len:
            #Randomize the hash.
            for b in 0 ..< hash.data.len:
                hash.data[b] = uint8(rand(255))
            inputs[i] = newSendInput(hash, rand(255))

        #Create the outputs.
        outputs = newSeq[SendOutput](rand(254) + 1)
        for o in 0 ..< outputs.len:
            outputs[o] = newSendOutput(wallet.next(last = uint32(s * 1000)).next(last = uint32(o * 1000)).publicKey, uint64(rand(high(int32))))

        #Create the Send.
        send = newSend(
            inputs,
            outputs
        )

        #The Meros protocol requires this signature be produced by the MuSig of every unique Wallet paid via the inputs.
        #Serialization/Parsing doesn't care at all.
        wallet.next(last = uint32(s * 1000)).sign(send)

        #mine the Send.
        send.mine("".pad(96, "aa").toHash(384))

        #Serialize it and parse it back.
        reloaded = send.serialize().parseSend()

        #Compare the Sends.
        compare(send, reloaded)

        #Test the serialized versions.
        assert(send.serialize() == reloaded.serialize())

    echo "Finished the Network/Serialize/Transactions/Send Test."
