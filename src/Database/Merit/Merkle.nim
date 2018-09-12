#Hash lib.
import ../../lib/Hash

#Merkle object.
import objects/MerkleObj
#Export the MerkleTree object.
export MerkleTree

#Create a Markle Tree.
proc newMerkleTree*(hashesArg: seq[SHA512Hash]): MerkleTree {.raises: [].} =
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
                newLeafObject("".toSHA512Hash()),
                newLeafObject("".toSHA512Hash()),
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

#Getters.
proc getHash*(tree: MerkleTree): SHA512Hash {.raises: [].} =
    cast[Branch](tree).getHash()
