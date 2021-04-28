import random

import ../../../../src/lib/Util
import ../../../../src/Wallet/[MinerWallet, Wallet]

import ../../../../src/Database/Transactions/Mint as MintFile
import ../../../../src/Database/Transactions/Claim

import ../../../../src/Network/Serialize/Transactions/[
  SerializeClaim,
  ParseClaim
]

import ../../../Fuzzed
import ../../../Database/Transactions/CompareTransactions

suite "SerializeClaim":
  setup:
    var
      inputs: seq[FundedInput]
      claim: Claim
      reloaded: Claim
      wallet: HDWallet = newWallet("").hd

  midFuzzTest "Serialize and parse.":
    inputs = newSeq[FundedInput](rand(254) + 1)
    for i in 0 ..< inputs.len:
      inputs[i] = newFundedInput(newRandomHash(), rand(255))

    claim = newClaim(inputs, wallet.publicKey)

    #The Meros protocol requires this signature be produced by the aggregate of every unique MinerWallet paid via the Mints.
    #Serialization/Parsing doesn't care at all.
    newMinerWallet().sign(claim)

    reloaded = claim.serialize().parseClaim()
    compare(claim, reloaded)
    check claim.serialize() == reloaded.serialize()
