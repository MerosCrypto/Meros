#MerkleTree test.
#Hashing lib.
import ../../../src/lib/SHA512

#Numerical libs.
import ../../../src/lib/BN
import ../../../src/lib/Base

#Merkle lib.
import ../../../src/Database/Merit/Merkle

var
    #First leaf.
    a: string = SHA512("01".toBN(16).toString(256))
    #Second leaf.
    b: string = SHA512("0F".toBN(16).toString(256))
    #Third leaf.
    c: string = SHA512("03".toBN(16).toString(256))

    #First hash.
    ab: string = SHA512(
        (a & b).toBN(16).toString(256)
    )
    #Second hash.
    cc: string = SHA512(
        (c & c).toBN(16).toString(256)
    )
    #Root hash.
    hash: string = SHA512(
        (ab & cc).toBN(16).toString(256)
    )

    #Create the MerkleTree.
    merkle: MerkleTree = newMerkleTree(@[
        a,
        b,
        c
    ])

#Test the results.
assert(hash == merkle.hash, "MerkleTree hash inequals what it should equal.")

echo "Finished the Database/Network/MerkleTree test."
