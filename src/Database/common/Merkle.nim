#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Math lib
import math

#Merkle Object.
type Merkle* = ref object
    case isLeaf*: bool
        of true:
            discard
        of false:
            left*: Merkle
            right*: Merkle
    hash*: Hash[384]

#Merkle constructor.
func newMerkle(
    hash: Hash[384]
): Merkle {.forceCheck: [].} =
    Merkle(
        isLeaf: true,
        hash: hash
    )

#Rehashes a Merkle Tree.
proc rehash(
    tree: Merkle
) {.forceCheck: [].} =
    #If this is a Leaf, its hash is constant.
    if tree.isLeaf:
        return

    #If the left tree is nil, meaning this is an empty tree, 0-out the hash.
    if tree.left.isNil:
        for i in 0 ..< 48:
            tree.hash.data[i] = 0
    #If there's an odd number of children, duplicate the left one.
    elif tree.right.isNil:
        tree.hash = Blake384(tree.left.hash.toString() & tree.left.hash.toString())
    #Hash the left & right hashes.
    else:
        tree.hash = Blake384(tree.left.hash.toString() & tree.right.hash.toString())

#Merkle constructor based on two other Merkles.
proc newMerkle(
    left: Merkle,
    right: Merkle
): Merkle {.forceCheck: [].} =
    result = Merkle(
        isLeaf: false,
        left: left,
        right: right
    )
    result.rehash()

#Opposite of isLeaf.
func isBranch(
    tree: Merkle
): bool {.inline, forceCheck: [].} =
    not tree.isLeaf

#Checks if this tree has any duplicated entries, anywhere.
func isFull(
    tree: Merkle
): bool {.forceCheck: [].} =
    if tree.isLeaf:
        return true

    if tree.right.isNil:
        return false

    result = tree.left.isFull and tree.right.isFull

#Returns the deptch of the tree.
func depth(
    tree: Merkle
): int {.forceCheck: [].} =
    if tree.isLeaf:
        return 0

    #We use tree.left because the left tree will alaways be non-nil.
    result = 1 + tree.left.depth

#Number of leaves.
func leafCount(
    tree: Merkle
): int {.forceCheck: [].} =
    if tree.isNil:
        return 0
    if tree.isLeaf:
        return 1
    result = tree.left.leafCount + tree.right.leafCount

#Creates a Merkle Tree out of a single hash, filling in duplicates.
proc chainOfDepth(
    depth: int,
    hash: Hash[384]
): Merkle {.forceCheck: [].} =
    if depth == 0:
        return newMerkle(hash)
    result = newMerkle(chainOfDepth(depth - 1, hash), nil)

#Adds a hash to a Merkle Tree.
proc add*(
    tree: var Merkle,
    hash: Hash[384]
) {.forceCheck: [].} =
    if tree.isLeaf:
        tree = newMerkle(tree, newMerkle(hash))
    elif tree.left.isNil:
        tree = newMerkle(
            newMerkle(hash),
            nil
        )
    elif tree.isFull:
        tree = newMerkle(tree, chainOfDepth(tree.depth, hash))
    elif tree.left.isBranch and not tree.left.isFull:
        tree.left.add(hash)
    elif tree.right.isNil:
        tree.right = chainOfDepth(tree.depth - 1, hash)
    else:
        tree.right.add(hash)

    tree.rehash()

#From https://stackoverflow.com/a/15327567/4608364.
const t: array[6, uint64] = [
    0xFFFFFFFF00000000'u64,
    0x00000000FFFF0000'u64,
    0x000000000000FF00'u64,
    0x00000000000000F0'u64,
    0x000000000000000C'u64,
    0x0000000000000002'u64
]
func ceilLog2(
    xArg: uint64
): uint64 {.forceCheck: [].} =
    var
        x: uint64 = xArg
        j: uint64 = 32
        y: uint64
        k: uint64

    if (x and (x - 1)) == 0:
        y = 0
    else:
        y = 1

    for i in 0 ..< 6:
        if (x and t[i]) == 0'u64:
            k = 0'u64
        else:
            k = j

        y += k
        x = x shr k
        j = j shr 1

    result = y

proc newMerkleAux(
    hashes: varargs[Hash[384]],
    targetDepth: int
): Merkle {.forceCheck: [].} =
    if targetDepth == 0:
        return newMerkle(hashes[0])

    let halfWidth: int = 2 ^ (targetDepth - 1)
    if hashes.len <= halfWidth:
        #We need to duplicate LHS on RHS.
        result = newMerkle(newMerkleAux(hashes, targetDepth - 1), nil)
    else:
        result = newMerkle(
            newMerkleAux(hashes[0 ..< halfWidth], targetDepth - 1),
            newMerkleAux(hashes[halfWidth ..< len(hashes)], targetDepth - 1)
        )
#Merkle constructor based on a seq or array of hashes (as strings).
proc newMerkle*(
    hashes: varargs[Hash[384]]
): Merkle {.forceCheck: [].} =
    #If there were no hashes, create a nil tree.
    if hashes.len == 0:
        return newMerkle(nil, nil)

    #Pass off to Merkle Aux.
    result = newMerkleAux(
        hashes,
        int(
            ceilLog2(uint64(hashes.len))
        )
    )

#Recursive function to trim a Merkle without cutting an entire branch.
proc trimAux(
    tree: Merkle,
    n: int
): Merkle {.forceCheck: [].} =
    if n == 0:
        return tree

    if n >= tree.right.leafCount:
        result = newMerkle(tree.left.trimAux(n - tree.right.leafCount), nil)
    else:
        result = newMerkle(tree.left, tree.right.trimAux(n))

#Nonmutatively remove the last N leaves from a tree.
proc trim*(
    treeArg: Merkle,
    nArg: int
): Merkle {.forceCheck: [].} =
    #Clone the arguments.
    var
        tree: Merkle = treeArg
        n: int = nArg

    #This code doesn't handle trimming everything BUT the initial leaf.
    #This override handles that.
    if tree.leafCount - n == 1:
        result = tree
        while result.isBranch:
            result = result.left
        return

    #Chop of the entire right branch for as long as we can.
    while (
        (n >= tree.right.leafCount) and
        (n > 0)
    ):
        n -= tree.right.leafCount
        tree = tree.left

    #Recursively handle the rest.
    result = tree.trimAux(n)
