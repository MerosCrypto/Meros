import ../../../src/lib/SHA512
import ../../../src/lib/Base
import ../../../src/Database/Merit/Merkle

var
    a: string = SHA512("01".toBN(16).toString(256))
    b: string = SHA512("0F".toBN(16).toString(256))
    c: string = SHA512("03".toBN(16).toString(256))

    merkle: MerkleTree = newMerkleTree(@[
        a,
        b,
        c
    ])

    ab: string = SHA512(
        (a & b).toBN(16).toString(256)
    )

    cc: string = SHA512(
        (c & c).toBN(16).toString(256)
    )

    hash: string = SHA512(
        (ab & cc).toBN(16).toString(256)
    )

echo "Hash:   " & hash
echo "Merkle: " & merkle.hash
