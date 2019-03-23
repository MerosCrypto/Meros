#Serialize Block Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#BLS/MinerWallet libs.
import ../../../../src/lib/BLS
import ../../../../src/Wallet/MinerWallet

#VerifierIndex and Miners objects.
import ../../../../src/Database/Merit/objects/VerifierIndexObj
import ../../../../src/Database/Merit/objects/MinersObj

#Block lib.
import ../../../../src/Database/Merit/Block

#Serialize libs.
import ../../../../src/Network/Serialize/Merit/SerializeBlock
import ../../../../src/Network/Serialize/Merit/ParseBlock

#Random standard lib.
import random

#Algorithm standard lib; used to randomize the Verifications/Miners order.
import algorithm

#Set the seed to be based on the time.
randomize(int(getTime()))

for i in 1 .. 20:
    echo "Testing Block Serialization/Parsing, iteration " & $i & "."

    var
        #Block.
        newBlock: Block
        #Nonce.
        nonce: uint = uint(rand(6500))
        #Last hash.
        last: Hash[512]
        #MinerWallet used to create random BLSSignatures.
        miner: MinerWallet = newMinerWallet()
        #Aggregate Signature.
        aggregate: BLSSignature
        #Verifications.
        verifs: seq[VerifierIndex]
        #Temporary key/merkle strings for creating VerifierIndexes.
        vKey: string
        vMerkle: string
        #Miners.
        miners: Miners = newSeq[Miner](rand(99) + 1)
        #Remaining Merit in the Block.
        remaining: int = 100
        #Amount of Merit to give each Miner.
        amount: int
        #Time.
        time: uint = uint(rand(2000000000))
        #Proof.
        proof: uint = uint(rand(500000))

    #Randomize the last hash.
    for b in 0 ..< 64:
        last.data[b] = uint8(rand(255))

    #Create a random BLSSignature.
    aggregate = miner.sign(rand(100000).toBinary())

    #Randomize the Verifications.
    for v in 0 ..< verifs.len:
        #Reset the key and merkle.
        vKey = newString(48)
        vMerkle = newString(64)

        #Randomize the key.
        for b in 0 ..< vKey.len:
            vKey[b] = char(rand(255))

        #Randomize the merkle.
        for b in 0 ..< vMerkle.len:
            vMerkle[b] = char(rand(255))

        verifs[v] = newVerifierIndex(
            vKey,
            uint(rand(100000)),
            vMerkle
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
        verifs,
        miners,
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
    assert(newBlock.header.verifications == blockParsed.header.verifications)
    assert(newBlock.header.miners == blockParsed.header.miners)
    assert(newBlock.header.time == blockParsed.header.time)
    assert(newBlock.header.proof == blockParsed.header.proof)

    #Test the hash.
    assert(newBlock.header.hash == blockParsed.header.hash)

    #Test the Verifications.
    for v in 0 ..< newBlock.verifications.len:
        assert(newBlock.verifications[v].key == blockParsed.verifications[v].key)
        assert(newBlock.verifications[v].nonce == blockParsed.verifications[v].nonce)
        assert(newBlock.verifications[v].merkle == blockParsed.verifications[v].merkle)

    #Test the Miners.
    for m in 0 ..< newBlock.miners.len:
        assert(newBlock.miners[m].miner == blockParsed.miners[m].miner)
        assert(newBlock.miners[m].amount == blockParsed.miners[m].amount)

echo "Finished the Network/Serialize/Merit/Block Test."
