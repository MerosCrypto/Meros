#Util lib.
import Util

#Hash lib.
import Hash

#Math lib
import math

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
        return 0

    #We use tree.left because the left tree will alaways be non-nil.
    return 1 + tree.left.depth

#Creates a Merkle Tree out of a single hash, filling in duplicates.
proc chainOfDepth(depth: int, hash: string): Merkle {.raises: [].} =
    if depth == 0:
        return newMerkle(hash)
    return newMerkle(chainOfDepth(depth - 1, hash), nil)

#Adds a hash to a Merkle Tree.
proc add*(tree: var Merkle, hash: string) {.raises: [].} =
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

# From https://stackoverflow.com/a/15327567/4608364
proc ceilLog2(x: uint64): uint64 =
  const t: array[6, uint64] = [
    0xFFFFFFFF00000000'u64,
    0x00000000FFFF0000'u64,
    0x000000000000FF00'u64,
    0x00000000000000F0'u64,
    0x000000000000000C'u64,
    0x0000000000000002'u64,
  ]
  var x: uint64 = x
  var y: uint64 = if (x and (x - 1)) == 0: 0 else: 1
  var j: uint64 = 32
  for i in 0 ..< 6:
    let k: uint64 = if (x and t[i]) == 0'u64: 0'u64 else: j
    y += k
    x = x shr k
    j = j shr 1
  return y

#forward declaration
proc newMerkleAux(hashes: openarray[string], targetDepth: int): Merkle {.raises: [].}

#Merkle constructor based on a seq or array of hashes (as strings).
proc newMerkle*(hashes: varargs[string]): Merkle {.raises: [].} =
    #If there were no hashes, create a nil tree.
    if hashes.len == 0:
        return newMerkle(nil, nil)

    let targetDepth = int(ceilLog2(uint64(len(hashes))))
    return newMerkleAux(hashes, targetDepth)

proc newMerkleAux(hashes: openarray[string], targetDepth: int): Merkle {.raises: [].} =
    if targetDepth == 0:
      assert(len(hashes) == 1)
      return newMerkle(hashes[0])

    #half of the number of items in the lowest level of the tree (if it were completely filled)
    let halfWidth = 2^(targetDepth-1)

    if len(hashes) <= halfWidth:
        # we need to duplicate LHS on RHS
        let lhs = newMerkleAux(hashes, targetDepth - 1)
        return newMerkle(lhs, lhs)
    else:
        let lhs = newMerkleAux(hashes[0 ..< halfWidth], targetDepth - 1)
        let rhs = newMerkleAux(hashes[halfWidth ..< len(hashes)], targetDepth - 1)
        return newMerkle(lhs, rhs)
