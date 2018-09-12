#Base lib.
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#Object definitions.
type
    #Leaf. The lowest type on the tree.
    Leaf* = ref object of RootObj
        isLeaf: bool
        hash: SHA512Hash

    #Branch. Everything from the leaves to the top.
    Branch* = ref object of Leaf
        empty: bool
        left: Leaf
        right: Leaf

    #MerkleTree. The master object.
    MerkleTree* = ref object of Branch

#Lead constructor.
proc newLeafObject*(hash: SHA512Hash): Leaf {.raises: [].} =
    Leaf(
        isLeaf: true,
        hash: hash
    )

#Branch constructor.
proc newBranchObject*(left: Leaf, right: Leaf, empty = false): Branch {.raises: [].} =
    result = Branch(
        isLeaf: false,
        left: left,
        right: right
    )

    if empty:
        result.empty = true
        result.hash = "".toSHA512Hash()
        return

    result.hash = SHA512(
        left.hash.toString() & right.hash.toString()
    )

#Getters.
proc getHash*(leaf: Leaf): SHA512Hash {.raises: [].} =
    leaf.hash
proc getIsLeaf*(leaf: Leaf): bool {.raises: [].} =
    leaf.isLeaf
proc getLeft*(leaf: Leaf): Leaf {.raises: [ValueError].} =
    if leaf.isLeaf:
        raise newException(ValueError, "Cannot get a leaf from a leaf.")

    result = cast[Branch](leaf).left
proc getRight*(leaf: Leaf): Leaf {.raises: [ValueError].} =
    if leaf.isLeaf:
        raise newException(ValueError, "Cannot get a leaf from a leaf.")

    result = cast[Branch](leaf).right
