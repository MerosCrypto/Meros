import Hash

type Merkle* = ref object
    # Though the API user will only interact with
    # this type as if it is a branch, we conflate
    # the branches and leaves into one type for the
    # sake of code elegance
    case isLeaf*: bool
    of true:
        discard
    of false:
        left*: Merkle
        right*: Merkle

    hash*: string

#[

There are some unstated gotchas that we use throughout this file.

1. Sometimes a function requires that a given Merkle is
   necessarily a leaf or necessarily a branch. Since the
   Merkle type can be either, this allows for a possible
   runtime error. However, this is not possible though
   the exposed API and must only be accounted for
   internally.

2. All Merkle trees are assumed to be nonempty. This is because
   it is out of the scope of the intended usecase, is conceptually
   tricky, and would result in hairier code.

3. The tree invariant: That
   (I) All leafs to the left of a non-nil leaf are non-nil,
   and all leafs to the right of a nil-nil are nil, and
   (II) All leaf nodes exist on the same depth.

   All the 'source' hashes of a Merkle tree, i.e., the leaves,
   can be conceptualized as existing in a sequence. Thus
   consider the 'source' hashes A, B, C, and D:

       A B C D

   From this sequence we buld the Merkle tree

             ABCD
         AB       CD
       A    B   C    D

    And we see that all the leaves exist on the same
    depth, and thus the reason for (II).

    The reason for (I) becomes clear when we consider adding
    a leaf E. Adding it to the sequence looks like:

        A B C D E

    In order to create the Merkle tree for this, we build
    it up as we had before, but we'll be missing some elements.
    We'll fill those in with "?".

                   ABCDE???
             ABCD           E???
         AB       CD     E?      ?? 
       A    B   C    D E    ?  ?    ?

    In practice, these "?"s are represented by `nil`. So (I)
    then reads:

        All leafs to the left of a non-"?" leaf are non-"?",
        and all leafs to the right of a non-"?" leaf are "?".

    See that it holds for this example, and also when we add
    another node F:

                   ABCDEF??
             ABCD           EF??
         AB       CD     EF      ?? 
       A    B   C    D E    F  ?    ?

   And intuitively should keep holding forever.

   Now, how the "?"s are treated is actually slightly
   subtle. Essentially, when combining two trees,
   if the right tree is missing (since ONLY the right
   tree can, due to (I)), we treat it as a duplicate
   of the left tree. Thus if we denote "copies" with
   lowercase letters, then

         A?        is treated as        Aa
       A    ?                         A    a

   And the previous large tree is treated as:

                   ABCDEFef
             ABCD           EFef
         AB       CD     EF      ef 
       A    B   C    D E    F

   See that the bottom-rightmost two leaves are disregarded
   entirely, since we can get the value of their parent, ef,
   from its sibling, EF.

]#

func isBranch(tree: Merkle): bool {.raises: [].} =
    return not tree.isLeaf

func depth(tree: Merkle): int {.raises: [].} =
    ## Depth of a Merkle tree. We consider a leaf to have depth 1 rather than 0.
    if tree.isLeaf:
        return 1
    else:
        return 1 + tree.left.depth

func newLeaf(hash: string): Merkle {.raises: [].} =
    result = Merkle(isLeaf: true, hash: hash)

proc rehash(tree: Merkle) {.raises: [].} =
    ## Recalculate the hash of a tree, based on its children if it's a branch.
    if tree.isLeaf:
        return
    if tree.right.isNil:
        tree.hash = SHA512(tree.left.hash & tree.left.hash).toString
    else:
        tree.hash = SHA512(tree.left.hash & tree.right.hash).toString

proc newBranch(left: Merkle, right: Merkle): Merkle {.raises: [].} =
    result = Merkle(isLeaf: false, hash: "", left: left, right: right)
    result.rehash()

func isFull(tree: Merkle): bool {.raises: [].} =
    ## Are all 2^depth leaf nodes populated?
    if tree.isLeaf:
        return true
    if tree.right.isNil:
        return false
    return tree.left.isFull and tree.right.isFull

func `$`(tree: Merkle): string {.raises: [].} =
    # Meant for use only in testing
    if tree.isLeaf:
        return tree.hash
    elif tree.right.isNil:
        return "(" & $tree.left & ", nil)"
    else:
        return "(" & $tree.left & ", " & $tree.right & ")"

proc chainOfDepth(depth: int, hash: string): Merkle {.raises: [].} =
    ## O(depth) method to create a Merkle tree populated only by leftmost items,
    ## terminating in a leaf.
    ## Thus is used when adding a new hash to a full tree, as illustrated in
    ## the big-ass comment way above (upon adding leaf E)
    assert depth >= 1  # A Merkle tree cannot be empty and thus must have a depth >= 1
    if depth == 1:
        return newLeaf(hash)
    else:
        return newBranch(chainOfDepth(depth - 1, hash), nil)

proc add*(tree: var Merkle, hash: string) {.raises: [].} =
    ## O(log n) method to add a hash to the tree
    if tree.isFull:
        let sibling = chainOfDepth(tree.depth, hash)
        let parent = newBranch(tree, sibling)
        tree = parent
    elif tree.left.isBranch and not tree.left.isFull:
        tree.left.add(hash)
    elif tree.right.isNil:
        tree.right = chainOfDepth(tree.depth - 1, hash)
    else:
        tree.right.add(hash)

    tree.rehash()

proc newMerkle*(hashes: openarray[string]): Merkle =
    ## O(n log n) method to create a tree from given hashes.
    ## Could be O(log n) in theory; if you want that, make it yourself.
    if hashes.len == 0:
        raise IndexError.newException("Merkle trees require 1 or more hashes")

    result = newLeaf(hashes[0])
    for hash in hashes[1 ..< hashes.len]:
        result.add(hash)
