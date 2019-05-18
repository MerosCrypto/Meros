#Serialize BlockBody Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../../src/Database/common/objects/MeritHolderRecordObj

#Miners and BlockBody object.
import ../../../../src/Database/Merit/objects/MinersObj
import ../../../../src/Database/Merit/objects/BlockBodyObj

#Serialize libs.
import ../../../../src/Network/Serialize/Merit/SerializeBlockBody
import ../../../../src/Network/Serialize/Merit/ParseBlockBody

#Random standard lib.
import random

#Algorithm standard lib; used to randomize the Records/Miners order.
import algorithm

#Seed Random via the time.
randomize(getTime())

for i in 1 .. 20:
    echo "Testing BlockBody Serialization/Parsing, iteration " & $i & "."

    var
        #BlockBody.
        body: BlockBody
        #MinerWallet used to create random BLSSignatures.
        miner: MinerWallet = newMinerWallet()
        #Records.
        records: seq[MeritHolderRecord] = newSeq[MeritHolderRecord](rand(256))
        #Temporary key/merkle strings for creating MeritHolderRecordes.
        rKey: string
        rMerkle: string
        #Miners.
        miners: seq[Miner] = newSeq[Miner](rand(99) + 1)
        #Remaining Merit in the Block.
        remaining: int = 100
        #Amount of Merit to give each Miner.
        amount: int

    #Randomize the Records.
    for r in 0 ..< records.len:
        #Reset the key and merkle.
        rKey = newString(48)
        rMerkle = newString(48)

        #Randomize the key.
        for b in 0 ..< rKey.len:
            rKey[b] = char(rand(255))

        #Randomize the merkle.
        for b in 0 ..< rMerkle.len:
            rMerkle[b] = char(rand(255))

        records[r] = newMeritHolderRecord(
            newBLSPrivateKeyFromSeed(rKey).getPublicKey(),
            rand(100000),
            rMerkle.toHash(384)
        )

    #Fill up the Miners.
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
            uint(amount)
        )

        #Subtract the amount from remaining.
        remaining -= amount

    #Randomly order the miners.
    miners.sort(
        proc (x: Miner, y: Miner): int =
            rand(1000)
    )

    #Create the BlockBody.
    body = newBlockBodyObj(
        records,
        newMinersObj(miners)
    )

    #Serialize it and parse it back.
    var bodyParsed: BlockBody = body.serialize().parseBlockBody()

    #Test the serialized versions.
    assert(body.serialize() == bodyParsed.serialize())

    #Test the Records.
    assert(body.records.len == bodyParsed.records.len)
    for r in 0 ..< body.records.len:
        assert(body.records[r].key == bodyParsed.records[r].key)
        assert(body.records[r].nonce == bodyParsed.records[r].nonce)
        assert(body.records[r].merkle == bodyParsed.records[r].merkle)

    #Test the Miners.
    assert(body.miners.miners.len == bodyParsed.miners.miners.len)
    for m in 0 ..< body.miners.miners.len:
        assert(body.miners.miners[m].miner == bodyParsed.miners.miners[m].miner)
        assert(body.miners.miners[m].amount == bodyParsed.miners.miners[m].amount)

echo "Finished the Network/Serialize/Merit/BlockBody Test."
