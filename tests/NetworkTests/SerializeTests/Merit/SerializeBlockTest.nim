#Serialize Block Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#BLS/MinerWallet libs.
import ../../../../src/lib/BLS
import ../../../../src/Wallet/MinerWallet

#Index object.
import ../../../../src/Database/common/objects/IndexObj

#Verifications lib.
import ../../../../src/Database/Verifications/Verifications

#Miners object.
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
        #Time.
        time: uint = uint(rand(2000000000))
        #Proof.
        proof: uint = uint(rand(500000))
        #Verifications.
        verifs: Verifications = newVerifications()
        #Verifiers.
        verifiers: seq[MinerWallet] = @[]
        #Verifier quantity.
        verifierQuantity: int = rand(99) + 1
        #Indexes.
        indexes: seq[Index] = @[]
        #Miners.
        miners: Miners = newSeq[Miner](rand(99) + 1)
        #Remaining Merit in the Block.
        remaining: int = 100
        #Amount of Verifications to create for the Verifier/of Merit to give each Miner.
        amount: int

    #Randomize the last hash.
    for b in 0 ..< 64:
        last.data[b] = uint8(rand(255))

    #Fill up the Verifiers.
    for v in 0 ..< verifierQuantity:
        verifiers.add(newMinerWallet())

    #Create Verifications.
    for verifier in verifiers:
        #Amount of Verifications.
        amount = rand(99) + 1
        #Add it to indexes.
        indexes.add(newIndex(verifier.publicKey.toString(), uint(amount - 1)))

        #Create the Verifications.
        for a in 0 ..< amount:
            var
                #Random hash to verify.
                hash: Hash[512]
                #Verification.
                verif: MemoryVerification

            #Randomize the hash.
            for b in 0 ..< 64:
                hash.data[b] = uint8(rand(255))

            #Create the Verification.
            verif = newMemoryVerificationObj(hash)
            verifier.sign(verif, uint(a))
            verifs.add(verif)

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
        verifs,
        nonce,
        last,
        indexes,
        miners,
        time,
        proof
    )

    #Serialize it and parse it back.
    var blockParsed: Block = newBlock.serialize(verifs).parseBlock(verifs)

    #Test the serialized versions.
    assert(newBlock.serialize(verifs) == blockParsed.serialize(verifs))

    #Test the Header.
    assert(newBlock.header.nonce == blockParsed.header.nonce)
    assert(newBlock.header.last == blockParsed.header.last)
    assert(newBlock.header.verifications == blockParsed.header.verifications)
    assert(newBlock.header.miners == blockParsed.header.miners)
    assert(newBlock.header.time == blockParsed.header.time)
    assert(newBlock.header.proof == blockParsed.header.proof)

    #Test the hash.
    assert(newBlock.hash == blockParsed.hash)

    #Test the Verifications.
    for v in 0 ..< newBlock.verifications.len:
        assert(newBlock.verifications[v].key == blockParsed.verifications[v].key)
        assert(newBlock.verifications[v].nonce == blockParsed.verifications[v].nonce)

    #Test the Miners.
    for m in 0 ..< newBlock.miners.len:
        assert(newBlock.miners[m].miner == blockParsed.miners[m].miner)
        assert(newBlock.miners[m].amount == blockParsed.miners[m].amount)

echo "Finished the Network/Serialize/Merit/Block test."
