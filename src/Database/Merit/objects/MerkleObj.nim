#Base lib.
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#SetOnce lib.
import SetOnce

#Object definitions.
type
    #Leaf. The lowest type on the tree.
    Leaf* = ref object of RootObj
        isLeaf*: SetOnce[bool]
        hash*: SetOnce[SHA512Hash]

    #Branch. Everything from the leaves to the top.
    Branch* = ref object of Leaf
        empty*: SetOnce[bool]
        left*: SetOnce[Leaf]
        right*: SetOnce[Leaf]

    #MerkleTree. The master object.
    MerkleTree* = ref object of Branch

#Lead constructor.
proc newLeafObject*(hash: SHA512Hash): Leaf {.raises: [ValueError].} =
    result = Leaf()
    result.isLeaf.value = true
    result.hash.value = hash

#Branch constructor.
proc newBranchObject*(left: Leaf, right: Leaf, empty = false): Branch {.raises: [ValueError].} =
    result = Branch()
    result.isLeaf.value = false
    result.left.value = left
    result.right.value = right

    if empty:
        result.empty.value = true
        result.hash.value = "".toSHA512Hash()
        return

    result.hash.value = SHA512(
        left.hash.toString() & right.hash.toString()
    )
