import math

import Errors, Hash

type Merkle* = ref object
  unset: bool
  case isLeaf*: bool
    of true:
      discard
    of false:
      left*: Merkle
      right*: Merkle
  hash*: Hash[256]

func newLeaf(): Merkle {.forceCheck: [].} =
  Merkle(
    unset: true,
    isLeaf: true
  )

func newLeaf(
  hash: Hash[256]
): Merkle {.forceCheck: [].} =
  Merkle(
    isLeaf: true,
    hash: hash
  )

proc rehash(
  tree: Merkle
) {.forceCheck: [].} =
  #If this is a Leaf, its hash is constant.
  if tree.isLeaf:
    return

  #If the left tree is nil, meaning this is an empty tree, 0-out the hash.
  if tree.left.isNil:
    for i in 0 ..< 32:
      tree.hash.data[i] = 0
  #If there's an odd number of children, duplicate the left one.
  elif tree.right.isNil:
    tree.hash = Blake256(tree.left.hash.serialize() & tree.left.hash.serialize())
  #Hash the left & right hashes.
  else:
    tree.hash = Blake256(tree.left.hash.serialize() & tree.right.hash.serialize())

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

#Checks if this tree has any duplicated transactions, anywhere.
func isFull(
  tree: Merkle
): bool {.forceCheck: [].} =
  if tree.isLeaf:
    return true
  elif tree.right.isNil:
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
  elif tree.isLeaf:
    return 1
  result = tree.left.leafCount + tree.right.leafCount

#Creates a Merkle Tree out of a single hash, filling in duplicates.
proc chainOfDepth(
  depth: int,
  hash: Hash[256]
): Merkle {.forceCheck: [].} =
  if depth == 0:
    return newLeaf(hash)
  result = newMerkle(chainOfDepth(depth - 1, hash), nil)

#Adds a hash to a Merkle Tree.
proc add*(
  tree: var Merkle,
  hash: Hash[256]
) {.forceCheck: [].} =
  if tree.unset:
    tree = newLeaf(hash)
    return
  elif tree.isLeaf:
    tree = newMerkle(tree, newLeaf(hash))
    return
  elif tree.left.isNil:
    tree = newMerkle(
      newLeaf(hash),
      nil
    )
    return
  elif tree.isFull:
    tree = newMerkle(tree, chainOfDepth(tree.depth, hash))
    return
  elif (not tree.left.isLeaf) and (not tree.left.isFull):
    tree.left.add(hash)
  elif tree.right.isNil:
    tree.right = chainOfDepth(tree.depth - 1, hash)
  else:
    tree.right.add(hash)

  tree.rehash()

#From https://stackoverflow.com/a/15327567/4608364.
#This should be replaced with a compiler intrinsic.
#bitops2 has some nice functions for this.
func ceilLog2(
  xArg: uint64
): uint64 {.forceCheck: [].} =
  const t: array[6, uint64] = [
    0xFFFFFFFF00000000'u64,
    0x00000000FFFF0000'u64,
    0x000000000000FF00'u64,
    0x00000000000000F0'u64,
    0x000000000000000C'u64,
    0x0000000000000002'u64
  ]

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
  hashes: varargs[Hash[256]],
  targetDepth: int
): Merkle {.forceCheck: [].} =
  if targetDepth == 0:
    return newLeaf(hashes[0])

  let halfWidth: int = 2 ^ (targetDepth - 1)
  if hashes.len <= halfWidth:
    #We need to duplicate LHS on RHS.
    result = newMerkle(newMerkleAux(hashes, targetDepth - 1), nil)
  else:
    result = newMerkle(
      newMerkleAux(hashes[0 ..< halfWidth], targetDepth - 1),
      newMerkleAux(hashes[halfWidth ..< len(hashes)], targetDepth - 1)
    )

proc newMerkle*(
  hashes: varargs[Hash[256]]
): Merkle {.forceCheck: [].} =
  #If there were no hashes, return a blank leaf.
  if hashes.len == 0:
    return newLeaf()

  #Pass off to Merkle Aux.
  result = newMerkleAux(hashes, int(ceilLog2(uint64(hashes.len))))
