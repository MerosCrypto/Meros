#Util lib.
import Util

#Hash lib.
import Hash

#Merkle Object.
type Merkle* = ref object of RootObj
    case isLeaf*: bool
        of true:
            discard
        of false:
            left*: Merkle
            right*: Merkle
    hash*: string

#Merkle constructor.
func newMerkle(hash: string): Merkle {.raises: [].} =
    Merkle(
        isLeaf: true,
        hash: hash
    )

#Rehashes a Merkle Tree.
proc rehash(tree: Merkle) {.raises: [].} =
    #If this is a Leaf, its hash is constant.
    if tree.isLeaf:
        return

    #If the left tree is nil, meaning this is an empty tree...
    if tree.left.isNil:
        tree.hash = "".pad(64)
    #If there's an odd number of children, duplicate the left one.
    elif tree.right.isNil:
        tree.hash = SHA512(tree.left.hash & tree.left.hash).toString()
    #Hash the left & right hashes.
    else:
        tree.hash = SHA512(tree.left.hash & tree.right.hash).toString()

#Merkle constructor based on two other Merkles.
proc newMerkle(left: Merkle, right: Merkle): Merkle {.raises: [].} =
    result = Merkle(
        isLeaf: false,
        left: left,
        right: right
    )
    result.rehash()

#Opposite of isLeaf.
func isBranch(tree: Merkle): bool {.raises: [].} =
    return not tree.isLeaf

#Checks if this tree has any duplicated entries, anywhere.
func isFull(tree: Merkle): bool {.raises: [].} =
    if tree.isLeaf:
        return true

    if tree.right.isNil:
        return false

    return tree.left.isFull and tree.right.isFull

#Returns the deptch of the tree.
func depth(tree: Merkle): int {.raises: [].} =
    if tree.isLeaf:
        return 1

    #We use tree.left because the left tree will alaways be non-nil.
    return 1 + tree.left.depth

#Creates a Merkle Tree out of a single hash, filling in duplicates.
proc chainOfDepth(depth: int, hash: string): Merkle {.raises: [].} =
    if depth == 1:
        return newMerkle(hash)
    return newMerkle(chainOfDepth(depth - 1, hash), nil)

#Adds a hash to a Merkle Tree.
proc add*(tree: var Merkle, hash: string) {.raises: [].} =
    if tree.left.isNil:
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

#Merkle constructor based on a seq or array of hashes (as strings).
proc newMerkle*(hashes: varargs[string]): Merkle {.raises: [].} =
    #If there were no hashes, create a nil tree.
    if hashes.len == 0:
        return newMerkle(nil, nil)

    result = newMerkle(
        newMerkle(hashes[0]),
        nil
    )
    for hash in hashes[1 ..< hashes.len]:
        result.add(hash)
