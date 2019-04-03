#Merkle Tree Test.

#Util lib.
import ../../src/lib/Util

#Hash lib.
import ../../src/lib/Hash

#Base lib.
import ../../src/lib/Base

#Merkle lib.
import ../../src/lib/Merkle

#Random standard lib.
import random

#Seq utils standard lib.
import sequtils

#Seed Random via the time.
randomize(int(getTime()))

#Test nil Merle trees.
assert(newMerkle().hash == "".pad(64))

#Test leaves.
assert(newMerkle("1".pad(64)).hash == "1".pad(64))

#Test 20 trees.
for i in 1 .. 20:
    echo "Testing Merkle Trees, iteration " & $i & "."

    #Create a random amount of hashes.
    var
        hashLen: int = rand(900) + 100
        hashes: seq[string] = newSeq[string](hashLen)
    for h in 0 ..< hashLen:
        hashes[h] = Blake512(h.toBinary()).toString()

    var
        #Copy the hashes so we can form our own tree of it (albeit slowly).
        fullCopy: seq[string] = hashes
        #Pick a random sub-amount for use in a Merkle tree created with both the constructor and addition.
        #The +1 is to make sure we don't skip the both test.
        bothLen: int = rand(hashLen - 2) + 1
        #Create a second copy of the hashes with this smaller range.
        partialCopy: seq[string] = hashes[0 ..< bothLen]
        #Define three trees. One of newMerkle, one of addition, and one of both.
        constructor: Merkle = newMerkle(hashes)
        addition: Merkle = newMerkle()
        both: Merkle = newMerkle(hashes[0 ..< bothLen])

    #Create the addition tree.
    for hash in hashes:
        addition.add(hash)

    #Generate our own tree, slowly, using fullCopy.
    #Run until we only have one hash.
    while fullCopy.len != 1:
        #Iterate over the seq by a 2 count.
        for h in countup(0, fullCopy.len - 1, 2):
            #If there is no h + 1, add the last hash again.
            if fullCopy.len mod 2 == 1:
                fullCopy.add(fullCopy[fullCopy.len - 1])

            #Turn fullCopy[h] into the branch hash for fullCopy[h .. h + 1].
            fullCopy[h] = Blake512(fullCopy[h] & fullCopy[h + 1]).toString()

        #Delete every other element.
        var d: int = 1
        while d < fullCopy.len:
            fullCopy.delete(d)
            inc(d)

    #Generate our own tree, slowly, using partialCopy.
    while partialCopy.len != 1:
        for h in countup(0, partialCopy.len - 1, 2):
            if partialCopy.len mod 2 == 1:
                partialCopy.add(partialCopy[partialCopy.len - 1])

            partialCopy[h] = Blake512(partialCopy[h] & partialCopy[h + 1]).toString()

        var d: int = 1
        while d < partialCopy.len:
            partialCopy.delete(d)
            inc(d)

    #Test that the constructor and addition tree have the same hash as fullCopy.
    assert(constructor.hash == fullCopy[0])
    assert(addition.hash == fullCopy[0])

    #Test that the both tree has the same hash as partialCopy.
    assert(both.hash == partialCopy[0])

    #Test that when hashLen - bothLen elements are trimmed, their hashes equal both's.
    assert(constructor.trim(hashLen - bothLen).hash == both.hash)
    assert(addition.trim(hashLen - bothLen).hash == both.hash)

    #Complete the both tree.
    for hash in hashes[bothLen ..< hashLen]:
        both.add(hash)

    #Test that the both tree and the fullCopy have the same hash.
    assert(both.hash == fullCopy[0])

    #Make sure trimming, as long as we don't break the lower bound, still works.
    assert(constructor.trim(hashLen div 2).hash == addition.trim(hashLen div 2).hash)

echo "Finished the lib/Merkle Test."
