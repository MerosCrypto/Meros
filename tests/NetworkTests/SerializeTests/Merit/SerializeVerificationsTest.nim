#Serialize Verifications Test.

#Util lib.
import ../../../../src/lib/Util

#VerifierIndex object.
import ../../../../src/Database/Merit/objects/VerifierIndexObj

#Serialize libs.
import ../../../../src/Network/Serialize/Merit/SerializeVerifications
import ../../../../src/Network/Serialize/Merit/ParseVerifications

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
        verifs: seq[VerifierIndex] = newSeq[VerifierIndex](rand(99) + 1)
        key: string
        nonce: uint
        merkle: string

    #Fill up the VerifierIndexes.
    for v in 0 ..< verifs.len:
        #Reset the key and merkle.
        key = newString(48)
        merkle = newString(64)

        #Randomize the key.
        for b in 0 ..< key.len:
            key[b] = char(rand(255))

        #Randomize the nonce.
        nonce = uint(rand(100000))

        #Randomize the merkle.
        for b in 0 ..< merkle.len:
            merkle[b] = char(rand(255))

        verifs[v] = newVerifierIndex(
            key,
            nonce,
            merkle
        )

    #Serialize it and parse it back.
    var verifsParsed: seq[VerifierIndex] = verifs.serialize().parseVerifications()

    #Test the serialized versions.
    assert(verifs.serialize() == verifsParsed.serialize())

    #Test the Verifications.
    for v in 0 ..< verifs.len:
        assert(verifs[v].key == verifsParsed[v].key)
        assert(verifs[v].nonce == verifsParsed[v].nonce)
        assert(verifs[v].merkle == verifsParsed[v].merkle)

echo "Finished the Network/Serialize/Merit/Verifications Test."
