#Serialize Verifications Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#VerifierIndex object.
import ../../../../src/Database/common/objects/VerifierIndexObj

#Serialize libs.
import ../../../../src/Network/Serialize/Merit/SerializeIndexes
import ../../../../src/Network/Serialize/Merit/ParseIndexes

#Random standard lib.
import random

#Algorithm standard lib; used to randomize the Verifications/Miners order.
import algorithm

#Seed Random via the time.
randomize(int(getTime()))

for i in 1 .. 20:
    echo "Testing Verifications Serialization/Parsing, iteration " & $i & "."

    var
        #seq of VerifierIndex.
        indexes: seq[VerifierIndex] = newSeq[VerifierIndex](rand(99) + 1)
        key: string
        nonce: int
        merkle: string

    #Fill up the VerifierIndexes.
    for v in 0 ..< indexes.len:
        #Reset the key and merkle.
        key = newString(48)
        merkle = newString(48)

        #Randomize the key.
        for b in 0 ..< key.len:
            key[b] = char(rand(255))

        #Randomize the nonce.
        nonce = rand(100000)

        #Randomize the merkle.
        for b in 0 ..< merkle.len:
            merkle[b] = char(rand(255))

        indexes[v] = newVerifierIndex(
            key,
            nonce,
            merkle.toHash(384)
        )

    #Serialize it and parse it back.
    var indexesParsed: seq[VerifierIndex] = indexes.serialize().parseIndexes()

    #Test the serialized versions.
    assert(indexes.serialize() == indexesParsed.serialize())

    #Test the Verifications.
    for v in 0 ..< indexes.len:
        assert(indexes[v].key == indexesParsed[v].key)
        assert(indexes[v].nonce == indexesParsed[v].nonce)
        assert(indexes[v].merkle == indexesParsed[v].merkle)

echo "Finished the Network/Serialize/Merit/Verifications Test."
