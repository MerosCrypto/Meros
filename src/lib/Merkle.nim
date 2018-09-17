#Base lib.
import Base

#Hash lib.
import Hash

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
        result.hash.value = SHA512("")
        return

    result.hash.value = SHA512(
        left.hash.toString() & right.hash.toString()
    )

#Create a Markle Tree.
proc newMerkleTree*(hashesArg: seq[SHA512Hash]): MerkleTree {.raises: [ValueError].} =
    var
        #Extract the hashes from its arg.
        hashes: seq[SHA512Hash] = hashesArg
        #Create a seq of the branches.
        branches: seq[Branch] = @[]
        #Create a left/right leaf.
        left: Leaf
        right: Leaf

    #If no hashes were passed in...
    if hashes.len == 0:
        return cast[MerkleTree](
            newBranchObject(
                newLeafObject(SHA512("")),
                newLeafObject(SHA512("")),
                true
            )
        )

    #Make sure we have an even amount of branches.
    if (hashes.len mod 2) == 1:
        hashes.add(hashes[hashes.len-1])

    #Iterate over the hashes.
    for i, hash in hashes:
        #If this is a left branch, use the Left leaf.
        if (i mod 2) == 0:
            left = newLeafObject(hash)
        else:
            #If this is a Right branch, use the Right leaf.
            right = newLeafObject(hash)
            #Now that we have a left and a right leaf, make a Branch.
            branches.add(newBranchObject(left, right))

    #While there's branches...
    while branches.len != 1:
        #If the branches are no longer even, add a copy of the last one.
        if (branches.len mod 2) == 1:
            branches.add(branches[branches.len-1])

        #Iterate through each pair of branches...
        for i in 0 ..< int(branches.len / 2):
            #Set the branch (on the left half of the seq) to involve two of the branches ahead of it.
            branches[i] = newBranchObject(branches[i * 2], branches[(i * 2) + 1])
        #Cut off the right half of the seq.
        branches.setLen((int) branches.len / 2)

    #Set the Result to the remaining branch.
    result = cast[MerkleTree](branches[0])
