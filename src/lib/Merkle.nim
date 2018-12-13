#Hash lib.
import Hash

#Object definitions.
type Merkle* = ref object
    case isLeaf*: bool
    of true:
        discard
    of false:
        left*: Merkle
        right*: Merkle

    hash*: string

func isBranch(tree: Merkle): bool {.raises: [].} =
    return not tree.isLeaf

func depth(tree: Merkle): int {.raises: [].} =
    if tree.isLeaf:
        return 1
    else:
        return 1 + tree.left.depth

func newMerkle(hash: string): Merkle {.raises: [].} =
    result = Merkle(isLeaf: true, hash: hash)

proc reHash(tree: Merkle) {.raises: [].} =
    if tree.isLeaf:
        return
    if tree.right.isNil:
        tree.hash = SHA512(tree.left.hash & tree.left.hash).toString
    else:
        tree.hash = SHA512(tree.left.hash & tree.right.hash).toString

proc newMerkle(left: Merkle, right: Merkle): Merkle {.raises: [].} =
    result = Merkle(isLeaf: false, hash: "", left: left, right: right)
    result.reHash()

func isFull(tree: Merkle): bool {.raises: [].} =
    if tree.isLeaf:
        return true

    if tree.right.isNil:
        return false

    return tree.left.isFull and tree.right.isFull

func `$`(tree: Merkle): string {.raises: [].} =
    if tree.isLeaf:
        return tree.hash
    elif tree.right.isNil:
        return "(" & $tree.left & ", nil)"
    else:
        return "(" & $tree.left & ", " & $tree.right & ")"

proc chainOfDepth(depth: int, hash: string): Merkle {.raises: [].} =
    assert depth >= 1
    if depth == 1:
        return newMerkle(hash)
    else:
        return newMerkle(chainOfDepth(depth - 1, hash), nil)

proc add*(tree: var Merkle, hash: string) {.raises: [].} =
    if tree.isFull:
        let sibling = chainOfDepth(tree.depth, hash)
        let parent = newMerkle(tree, sibling)
        tree = parent
    elif tree.left.isBranch and not tree.left.isFull:
        tree.left.add(hash)
    elif tree.right.isNil:
        tree.right = chainOfDepth(tree.depth - 1, hash)
    else:
        tree.right.add(hash)

    tree.reHash()

proc newMerkle*(hashes: varargs[string]): Merkle =
    if hashes.len == 0:
        raise IndexError.newException("Merkle trees require 1 or more hashes")

    result = newMerkle(hashes[0])
    for hash in hashes[1 ..< hashes.len]:
        result.add(hash)

when isMainModule:
    proc hash(s1, s2: string): string =
        SHA512(s1 & s2).toString

    assert(newMerkle("a", "b", "c", "d").hash == hash(hash("a", "b"), hash("c", "d")) )

    assert(newMerkle("1", "2", "3", "4", "5", "6", "7", "8").hash ==
            hash(hash(hash("1", "2"), hash("3", "4")), hash(hash("5", "6"), hash("7", "8"))) )

    assert(newMerkle("1", "2", "3").hash == hash(hash("1", "2"), hash("3", "3")) )

    block:
        var m = newMerkle("naughty")
        assert m.hash == "naughty"

        m.add("children")
        let h1 = hash("naughty", "children")
        assert m.hash == h1

        m.add("get")
        assert m.hash == hash(h1, hash("get", "get"))

        m.add("coal")
        let h2 = hash(h1, hash("get", "coal"))
        assert m.hash == h2

        m.add("for")
        assert m.hash == hash(h2, hash(hash("for", "for"), hash("for", "for")))

        m.add("christmas")
        assert m.hash == hash(h2, hash(hash("for", "christmas"), hash("for", "christmas")))
