import ../src/lib/SHA512
import ../src/DB/Merit/Merkle

var
    merkle: MerkleTree = newMerkleTree(@[
        "1",
        "F",
        "3"
    ])
    hash: string = SHA512(
        SHA512($((char) 31)) &
        SHA512($((char) 51))
    )

echo merkle.hash
echo hash
