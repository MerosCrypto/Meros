#Merkle Tree Test.

#Util lib.
import ../../src/lib/Util

#Hash lib.
import ../../src/lib/Hash

#Base lib.
import ../../src/lib/Base

#Merkle lib.
import ../../src/lib/Merkle

var
    #First leaf.
    a: string = SHA512("a").toString()
    #Second leaf.
    b: string = SHA512("b").toString()
    #Third leaf.
    c: string = SHA512("c").toString()

    #First hash.
    ab: string = SHA512(
        a & b
    ).toString()
    #Second hash.
    cc: string = SHA512(
        c & c
    ).toString()
    #Root hash.
    hash: string = SHA512(
        ab & cc
    ).toString()

    #Create the Merkle Tree.
    merkle: Merkle = newMerkle(a, b, c)

#Test the results.
assert(hash == merkle.hash, "Merkle hash is not what it should be.")

#Test nil Merle trees.
assert(newMerkle().hash == "".pad(64))

#Test adding hashes.
merkle = newMerkle(a)
merkle.add(b)
merkle.add(c)
assert(merkle.hash == hash)

merkle = newMerkle()
merkle.add(a)
merkle.add(b)
merkle.add(c)
assert(merkle.hash == hash)

echo "Finished the lib/Merkle test."
