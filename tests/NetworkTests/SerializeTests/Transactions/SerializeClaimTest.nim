#Serialize Claim Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Wallet libs.
import ../../../../src/Wallet/HDWallet
import ../../../../src/Wallet/MinerWallet

#Mint and Claim lib.
import ../../../../src/Database/Transactions/Mint as MintFile
import ../../../../src/Database/Transactions/Claim

#Serialize libs.
import ../../../../src/Network/Serialize/Transactions/SerializeClaim
import ../../../../src/Network/Serialize/Transactions/SerializeTransaction
import ../../../../src/Network/Serialize/Transactions/ParseClaim
import ../../../../src/Network/Serialize/Transactions/ParseTransaction

#Compare Transactions lib.
import ../../../DatabaseTests/TransactionsTests/CompareTransactions

#Random standard lib.
import random

#Seed Random via the time.
randomize(getTime())

var
    #Mints.
    mints: seq[Mint]
    #Claim.
    claim: Claim
    #Reloaded Claim.
    reloaded: Claim

#Test 255 serializations.
for s in 0 .. 255:
    #Create Mints.
    mints = newSeq[Mint](rand(254) + 1)
    for m in 0 ..< mints.len:
        mints[m] = newMint(
            rand(high(int32)),
            newMinerWallet().publicKey,
            uint64(rand(high(int32)))
        )

    #Create the Claim.
    claim = newClaim(
        mints,
        newHDWallet().publicKey
    )

    #The Meros protocol requires this signature be produced by the aggregate of every unique MinerWallet paid via the Mints.
    #Serialization/Parsing doesn't care at all.
    newMinerWallet().sign(claim)

    #Serialize it and parse it back.
    reloaded = claim.serialize().parseClaim()

    #Compare the Claims.
    compare(claim, reloaded)

    #Test the serialized versions.
    assert(claim.serialize() == reloaded.serialize())

    #Test Transaction.serialize() and Transaction.parse().
    reloaded = cast[Claim](("\1" & cast[Transaction](claim).serialize()).parseTransaction())
    compare(claim, reloaded)
    assert(cast[Transaction](claim).serialize() == cast[Transaction](reloaded).serialize())
    assert(cast[Transaction](claim).serialize() == claim.serialize())

echo "Finished the Network/Serialize/Transactions/Claim Test."
