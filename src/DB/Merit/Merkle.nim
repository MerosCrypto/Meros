import ../../lib/SHA512

type
    Leaf = ref object of RootObj
        isLeaf: bool
        hash*: string

    Branch = ref object of Leaf
        left: Leaf
        right: Leaf

    MerkleTree* = ref object of Branch

proc newLeaf(isLeaf: bool, hash: string): Leaf {.raises: [].} =
    Leaf(
        isLeaf: isLeaf,
        hash: hash
    )

proc newBranch(left: Leaf, right: Leaf): Branch {.raises: [].} =
    Branch(
        isLeaf: false,
        hash: SHA512(left.hash & right.hash),
        left: left,
        right: right
    )

proc newMerkleTree*(hashesArg: seq[string]): MerkleTree {.raises: [].} =
    if hashesArg.len == 0:
        result = MerkleTree(
            left: Leaf(
                isLeaf: true,
                hash: ""
            ),
            right: Leaf(
                isLeaf: true,
                hash: ""
            )
        )
        return

    var
        hashes: seq[string] = hashesArg
        branches: seq[Branch] = @[]
        left: Leaf
        right: Leaf

    if (hashes.len mod 2) == 1:
        hashes.add(hashes[hashes.len-1])
    for i in 0 ..< hashes.len:
        if (i mod 2) == 0:
            left = newLeaf(true, hashes[i])
        else:
            right = newLeaf(true, hashes[i])
            branches.add(newBranch(left, right))

    while branches.len != 1:
        if (branches.len mod 2) == 1:
            branches.add(branches[branches.len-1])
        for i in 0 ..< ((int) branches.len / 2):
            branches[i] = newBranch(branches[i * 2], branches[(i * 2) + 1])
        branches.setLen((int) branches.len / 2)

    result = cast[MerkleTree](branches[0])
