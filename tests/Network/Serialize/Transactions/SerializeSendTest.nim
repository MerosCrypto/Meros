#Serialize Send Test.

import unittest

#Fuzzing lib.
import ../../../Fuzzed

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
import ../../../Database/Transactions/CompareTransactions

#Random standard lib.
import random

suite "SerializeSend":
    setup:
        var
            #Hash used to create an input.
            hash: Hash[256]
            #Inputs.
            inputs: seq[FundedInput]
            #Outputs.
            outputs: seq[SendOutput]
            #Send.
            send: Send
            #Reloaded Send.
            reloaded: Send
            #Wallet.
            wallet: Wallet = newWallet("")

    midFuzzTest "Serialize and parse.":
        #Create the inputs.
        inputs = newSeq[FundedInput](rand(254) + 1)
        for i in 0 ..< inputs.len:
            #Randomize the hash.
            for b in 0 ..< hash.data.len:
                hash.data[b] = uint8(rand(255))
            inputs[i] = newFundedInput(hash, rand(255))

        #Create the outputs.
        outputs = newSeq[SendOutput](rand(254) + 1)
        for o in 0 ..< outputs.len:
            outputs[o] = newSendOutput(
                wallet
                .next(last = uint32(rand(200) * 1000))
                .next(last = uint32(o * 1000)).publicKey,
                uint64(rand(high(int32))))

        #Create the Send.
        send = newSend(
            inputs,
            outputs
        )

        #The Meros protocol requires this signature be produced by the MuSig of every unique Wallet paid via the inputs.
        #Serialization/Parsing doesn't care at all.
        wallet.next(last = uint32(rand(200) * 1000)).sign(send)

        #mine the Send.
        send.mine("".pad(64, "aa").toHash(256))

        #Serialize it and parse it back.
        reloaded = send.serialize().parseSend(Hash[256]())

        #Compare the Sends.
        compare(send, reloaded)

        #Test the serialized versions.
        check(send.serialize() == reloaded.serialize())
