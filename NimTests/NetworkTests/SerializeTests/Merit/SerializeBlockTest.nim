#Serialize Block Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../../src/Database/common/objects/MeritHolderRecordObj

#Miner object.
import ../../../../src/Database/Merit/objects/MinersObj

#BlockHeader and Block libs.
import ../../../../src/Database/Merit/BlockHeader
import ../../../../src/Database/Merit/Block

#Serialize lib.
import ../../../../src/Network/Serialize/Merit/SerializeBlock
import ../../../../src/Network/Serialize/Merit/ParseBlock

#Compare Merit lib.
import ../../../DatabaseTests/MeritTests/CompareMerit

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #Last Block's Hash.
        last: ArgonHash
        #Miners Hash.
        minersHash: Blake384Hash
        #Block Header.
        header: BlockHeader
        #Hash.
        hash: Hash[384]
        #Records.
        records: seq[MeritHolderRecord]
        #Miners.
        miners: seq[Miner]
        #Remaining amount of Merit.
        remaining: int = 100
        #Amount to pay this miner.
        amount: int
        #Block Body.
        body: BlockBody
        #Block.
        testBlock: Block
        #Reloaded Block.
        reloaded: Block

    #Test 255 serializations.
    for s in 0 .. 255:
        #Randomize the hashes.
        for b in 0 ..< 48:
            last.data[b] = uint8(rand(255))
            minersHash.data[b] = uint8(rand(255))

        #Create the BlockHeaader.
        header = newBlockHeader(
            rand(high(int32)),
            last,
            newMinerWallet().sign(rand(high(int32)).toBinary()),
            minersHash,
            uint32(rand(high(int32))),
            uint32(rand(high(int32)))
        )

        #Randomize the records.
        records = @[]
        for _ in 0 ..< s:
            for b in 0 ..< 48:
                hash.data[b] = uint8(rand(255))

            records.add(
                newMeritHolderRecord(
                    newMinerWallet().publicKey,
                    rand(high(int32)),
                    hash
                )
            )

        #Randomize the miners.
        miners = newSeq[Miner](rand(99) + 1)
        remaining = 100
        for m in 0 ..< miners.len:
            #Set the amount to pay the miner.
            amount = rand(remaining - 1) + 1
            #Make sure everyone gets at least 1 and we don't go over 100.
            if (remaining - amount) < (miners.len - m):
                amount = 1
            #But if this is the last account...
            if m == miners.len - 1:
                amount = remaining

            #Set the Miner.
            miners[m] = newMinerObj(
                newMinerWallet().publicKey,
                amount
            )

            #Subtract the amount from remaining.
            remaining -= amount

        #Create the BlockBody.
        body = newBlockBodyObj(
            records,
            newMinersObj(miners)
        )

        #Create the Block.
        testBlock = newBlockObj(header, body)

        #Serialize it and parse it back.
        reloaded = testBlock.serialize().parseBlock()

        #Test the serialized versions.
        assert(testBlock.serialize() == reloaded.serialize())

        #Compare the Blocks.
        compare(testBlock, reloaded)

    echo "Finished the Network/Serialize/Merit/Block Test."
