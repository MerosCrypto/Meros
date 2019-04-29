#Serialize Block Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#VerifierRecord object.
import ../../../../src/Database/common/objects/VerifierRecordObj

#Miner object.
import ../../../../src/Database/Merit/objects/MinersObj

#BlockHeader and Block lib.
import ../../../../src/Database/Merit/BlockHeader
import ../../../../src/Database/Merit/Block

#Serialize libs.
import ../../../../src/Network/Serialize/Merit/SerializeBlock
import ../../../../src/Network/Serialize/Merit/ParseBlock

#Random standard lib.
import random

#Algorithm standard lib; used to randomize the Records/Miners order.
import algorithm

#Seed Random via the time.
randomize(int(getTime()))

for i in 1 .. 20:
    echo "Testing Block Serialization/Parsing, iteration " & $i & "."

    var
        #Block.
        newBlock: Block
        #Nonce.
        nonce: int = rand(6500)
        #Last hash.
        last: Hash[384]
        #MinerWallet used to create random BLSSignatures.
        miner: MinerWallet = newMinerWallet()
        #Aggregate Signature.
        aggregate: BLSSignature
        #Records.
        records: seq[VerifierRecord] = newSeq[VerifierRecord](rand(384))
        #Temporary key/merkle strings for creating VerifierRecordes.
        vKey: string
        vMerkle: string
        #Miners.
        miners: seq[Miner] = newSeq[Miner](rand(99) + 1)
        #Remaining Merit in the Block.
        remaining: int = 100
        #Amount of Merit to give each Miner.
        amount: int
        #Time.
        time: int = rand(2000000000)
        #Proof.
        proof: int = rand(500000)

    #Randomize the last hash.
    for b in 0 ..< 48:
        last.data[b] = uint8(rand(255))

    #Create a random BLSSignature.
    aggregate = miner.sign(rand(100000).toBinary())

    #Randomize the Records.
    for v in 0 ..< records.len:
        #Reset the key and merkle.
        vKey = newString(48)
        vMerkle = newString(48)

        #Randomize the key.
        for b in 0 ..< vKey.len:
            vKey[b] = char(rand(255))

        #Randomize the merkle.
        for b in 0 ..< vMerkle.len:
            vMerkle[b] = char(rand(255))

        records[v] = newVerifierRecord(
            newBLSPrivateKeyFromSeed(vKey).getPublicKey(),
            rand(100000),
            vMerkle.toHash(384)
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

    #Create the Block.
    newBlock = newBlockObj(
        nonce,
        last,
        aggregate,
        records,
        newMinersObj(miners),
        time,
        proof
    )

    #Serialize it and parse it back.
    var blockParsed: Block = newBlock.serialize().parseBlock()

    #Test the serialized versions.
    assert(newBlock.serialize() == blockParsed.serialize())

    #Test the Header.
    assert(newBlock.header.nonce == blockParsed.header.nonce)
    assert(newBlock.header.last == blockParsed.header.last)
    assert(newBlock.header.aggregate == blockParsed.header.aggregate)
    assert(newBlock.header.miners == blockParsed.header.miners)
    assert(newBlock.header.time == blockParsed.header.time)
    assert(newBlock.header.proof == blockParsed.header.proof)

    #Test the hash.
    assert(newBlock.header.hash == blockParsed.header.hash)

    #Test the Records.
    assert(newBlock.records.len == blockParsed.records.len)
    for v in 0 ..< newBlock.records.len:
        assert(newBlock.records[v].key == blockParsed.records[v].key)
        assert(newBlock.records[v].nonce == blockParsed.records[v].nonce)
        assert(newBlock.records[v].merkle == blockParsed.records[v].merkle)

    #Test the Miners.
    assert(newBlock.miners.miners.len == blockParsed.miners.miners.len)
    for m in 0 ..< newBlock.miners.miners.len:
        assert(newBlock.miners.miners[m].miner == blockParsed.miners.miners[m].miner)
        assert(newBlock.miners.miners[m].amount == blockParsed.miners.miners[m].amount)

echo "Finished the Network/Serialize/Merit/Block Test."
