#Base lib.
import ../../../lib/Base

#SHA512 lib.
import ../../../lib/SHA512

#Object definitions.
type
    #Leaf. The lowest type on the tree.
    Leaf* = ref object of RootObj
        isLeaf: bool
        hash: string

    #Branch. Everything from the leaves to the top.
    Branch* = ref object of Leaf
        left: Leaf
        right: Leaf

    #MerkleTree. The master object.
    MerkleTree* = ref object of Branch

#Lead constructor.
proc newLeafObject*(hash: string): Leaf {.raises: [].} =
    Leaf(
        isLeaf: true,
        hash: hash
    )

#Branch constructor.
proc newBranchObject*(left: Leaf, right: Leaf, empty = false): Branch {.raises: [ValueError].} =
    result = Branch(
        isLeaf: false,
        left: left,
        right: right
    )

    if empty:
        result.hash = ""
        return

    result.hash = SHA512(
        (left.hash & right.hash).toBN(16).toString(256)
    )

#Getters.
proc getHash*(leaf: Leaf): string {.raises: [].} =
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
