import random

import ../../../../src/lib/Util
import ../../../../src/Wallet/Wallet

import ../../../../src/Database/Transactions/Send

import ../../../../src/Network/Serialize/Transactions/[
  SerializeSend,
  ParseSend
]

import ../../../Fuzzed
import ../../../Database/Transactions/CompareTransactions

suite "SerializeSend":
  setup:
    var
      inputs: seq[FundedInput]
      outputs: seq[SendOutput]
      send: Send
      reloaded: Send
      wallet: HDWallet = newWallet("").hd

  midFuzzTest "Serialize and parse.":
    #Create the inputs.
    inputs = newSeq[FundedInput](rand(254) + 1)
    for i in 0 ..< inputs.len:
      inputs[i] = newFundedInput(newRandomHash(), rand(255))

    #Create the outputs.
    outputs = newSeq[SendOutput](rand(254) + 1)
    for o in 0 ..< outputs.len:
      outputs[o] = newSendOutput(wallet.publicKey, uint64(rand(high(int32))))

    #Create the Send.
    send = newSend(inputs, outputs)

    #The Meros protocol requires this signature be produced by the MuSig of every unique Wallet paid via the inputs.
    #Serialization/Parsing doesn't care at all.
    wallet.sign(send)

    #mine the Send.
    send.mine(uint32(3))

    reloaded = send.serialize().parseSend(uint32(0))
    compare(send, reloaded)
    check send.serialize() == reloaded.serialize()
