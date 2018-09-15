#Merkle Tree Test.

#Hash lib.
import ../../src/lib/Hash

#Numerical libs.
import BN
import ../../src/lib/Base

#Merkle lib.
import ../../src/lib/Merkle

#SetOnce lib.
import SetOnce

var
    #First leaf.
    a: SHA512Hash = SHA512("01".toBN(16).toString(256))
    #Second leaf.
    b: SHA512Hash = SHA512("0F".toBN(16).toString(256))
    #Third leaf.
    c: SHA512Hash = SHA512("03".toBN(16).toString(256))

    #First hash.
    ab: SHA512Hash = SHA512(
        a.toString() & b.toString()
    )
    #Second hash.
    cc: SHA512Hash = SHA512(
        c.toString() & c.toString()
    )
    #Root hash.
    hash: SHA512Hash = SHA512(
        ab.toString() & cc.toString()
    )

    #Create the MerkleTree.
    merkle: MerkleTree = newMerkleTree(@[
        a,
        b,
        c
    ])

#Test the results.
assert(hash == merkle.hash, "MerkleTree hash is not what it should be.")

echo "Finished the lib/MerkleTree test."
