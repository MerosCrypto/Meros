#Serialize Block Test.

#Serialize BlockHeader Test.

#Util lib.
import ../../../../src/lib/Util

#Hash and Merkle libs.
import ../../../../src/lib/Hash
import ../../../../src/lib/Merkle

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Element lib.
import ../../../../src/Database/Consensus/Element

#Block lib.
import ../../../../src/Database/Merit/Block

#Serialize lib.
import ../../../../src/Network/Serialize/Merit/SerializeBlock
import ../../../../src/Network/Serialize/Merit/ParseBlock

#Test and Compare Merit libs.
import ../../../DatabaseTests/MeritTests/TestMerit
import ../../../DatabaseTests/MeritTests/CompareMerit

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    var
        #Hash.
        hash: Hash[384]
        #Last hash.
        last: ArgonHash
        #Verifiers hash.
        verifiers: Hash[384]
        #Transactions.
        transactions: seq[Hash[384]] = @[]
        #Elements.
        elements: seq[Element] = @[]
        #Contents Merkle tree.
        contents: Merkle
        #Block.
        newBlock: Block
        #Reloaded Block.
        reloaded: Block

    #Test 255 serializations.
    for s in 0 .. 255:
        #Randomize the last hash and the verifiers hash.
        for b in 0 ..< 48:
            last.data[b] = uint8(rand(255))
            verifiers.data[b] = uint8(rand(255))

        #Randomize the transactions.
        for _ in 0 ..< rand(300):
            for b in 0 ..< 48:
                hash.data[b] = uint8(rand(255))
            transactions.add(hash)

        #Randomize the elements.

        #Create the contents merkle.
        contents = newMerkle(transactions)
        for elem in elements:
            discard

        if s < 128:
            newBlock = newBlankBlock(
                uint32(rand(4096)),
                last,
                contents.hash,
                verifiers,
                newMinerWallet(),
                transactions,
                elements,
                newMinerWallet().sign($rand(4096)),
                uint32(rand(high(int32))),
                uint32(rand(high(int32)))
            )
        else:
            newBlock = newBlankBlock(
                uint32(rand(4096)),
                last,
                contents.hash,
                verifiers,
                uint32(rand(high(int32))),
                newMinerWallet(),
                transactions,
                elements,
                newMinerWallet().sign($rand(4096)),
                uint32(rand(high(int32))),
                uint32(rand(high(int32)))
            )

        #Serialize it and parse it back.
        reloaded = newBlock.serialize().parseBlock()

        #Test the serialized versions.
        assert(newBlock.serialize() == reloaded.serialize())

        #Compare the BlockBodies.
        compare(newBlock, reloaded)

    echo "Finished the Network/Serialize/Merit/Block Test."
