#Serialize Block Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#BLS/MinerWallet libs.
import ../../../../src/lib/BLS
import ../../../../src/Database/Merit/MinerWallet

#Miners object.
import ../../../../src/Database/Merit/objects/MinersObj

#Verifications and Block libs.
import ../../../../src/Database/Merit/Verifications
import ../../../../src/Database/Merit/Block

#Serialize lib.
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
        #Verifications.
        verifs: Verifications = newVerificationsObj()
        #Verification quantity.
        verifQuantity: int = rand(200) + 1
        #Miners.
        miners: Miners = newSeq[Miner](rand(99) + 1)
        #Remaining Merit in the Block.
        remaining: int = 100
        #Amount to give each Miner.
        amount: int

    #Randomize the last hash.
    for b in 0 ..< 64:
        last.data[b] = uint8(rand(255))

    #Fill up the Verifications.
    for v in 0 ..< verifQuantity:
        var
            #Random hash to verify.
            hash: Hash[512]
            #Verifier.
            verifier: MinerWallet = newMinerWallet()
            #Verification.
            verif: MemoryVerification

        #Randomize the hash.
        for b in 0 ..< 64:
            hash.data[b] = uint8(rand(255))

        #Create the Verification.
        verif = newMemoryVerification(hash)
        verifier.sign(verif)
        verifs.verifications.add(verif)

    #Calculate the Verifications sig.
    verifs.calculateSig()

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
    newBlock = newBlock(
        nonce,
        last,
        verifs,
        miners,
        uint(rand(2000000000)),
        uint(rand(65000)),
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

    #Test the Proof/Hashes.
    assert(newBlock.proof == blockParsed.proof)
    assert(newBlock.hash == blockParsed.hash)
    assert(newBlock.argon == blockParsed.argon)

    #Test the Verifications.
    for v in 0 ..< newBlock.verifications.verifications.len:
        assert(newBlock.verifications.verifications[v].verifier == blockParsed.verifications.verifications[v].verifier)
        assert(newBlock.verifications.verifications[v].hash == blockParsed.verifications.verifications[v].hash)
    assert(newBlock.verifications.aggregate == blockParsed.verifications.aggregate)

    #Test the Miners.
    for m in 0 ..< newBlock.miners.len:
        assert(newBlock.miners[m].miner == blockParsed.miners[m].miner)
        assert(newBlock.miners[m].amount == blockParsed.miners[m].amount)

echo "Finished the Network/Serialize/Merit/Block test."
