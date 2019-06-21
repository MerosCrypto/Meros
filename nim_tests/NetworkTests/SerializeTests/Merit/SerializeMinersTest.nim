#Serialize Miners Test.

#Util lib.
import ../../../../src/lib/Util

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Miners object.
import ../../../../src/Database/Merit/objects/MinersObj

#Serialize libs.
import ../../../../src/Network/Serialize/Merit/SerializeMiners
import ../../../../src/Network/Serialize/Merit/ParseMiners

#Compare Merit lib.
import ../../../DatabaseTests/MeritTests/CompareMerit

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    var
        #Miner Seq.
        minerSeq: seq[Miner]
        #Remaining amount of Merit.
        remaining: int
        #Amount to pay this miner.
        amount: int
        #Miners.
        miners: Miners
        #Reloaded Miners.
        reloaded: Miners

    #Test 255 serializations.
    for _ in 0 .. 255:
        #Randomize the miners.
        minerSeq = newSeq[Miner](rand(99) + 1)
        remaining = 100
        for m in 0 ..< minerSeq.len:
            #Set the amount to pay the miner.
            amount = rand(remaining - 1) + 1
            #Make sure everyone gets at least 1 and we don't go over 100.
            if (remaining - amount) < (minerSeq.len - m):
                amount = 1
            #But if this is the last account...
            if m == minerSeq.len - 1:
                amount = remaining

            #Set the Miner.
            minerSeq[m] = newMinerObj(
                newMinerWallet().publicKey,
                amount
            )

            #Subtract the amount from remaining.
            remaining -= amount

        #Create the Miners.
        miners = newMinersObj(minerSeq)

        #Serialize it and parse it back.
        reloaded = miners.serialize().parseMiners()

        #Test the serialized versions.
        assert(miners.serialize() == reloaded.serialize())

        #Compare the Miners-s.
        compare(miners, reloaded)

    echo "Finished the Network/Serialize/Merit/Miners Test."
