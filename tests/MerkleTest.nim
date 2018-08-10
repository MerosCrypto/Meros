import ../src/lib/SHA512
import ../src/Merit/Merkle

var
    merkle: MerkleTree = newMerkleTree(@[
        "1",
        "F",
        "3"
    ])
    hash = SHA512(SHA512("1" & "F") & SHA512("3" & "3"))

echo merkle.hash
echo hash
