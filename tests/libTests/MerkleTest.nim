#Merkle Tree Test.

#Hash lib.
import ../../src/lib/Hash

#Merkle lib.
import ../../src/lib/Merkle

#Util lib
import ../../src/lib/Util

proc hash(s1, s2: string): string =
    SHA512(s1 & s2).toString

assert(newMerkle().hash == "".pad(64))

assert(newMerkle(["a", "b", "c", "d"]).hash == hash(hash("a", "b"), hash("c", "d")) )

assert(newMerkle(["1", "2", "3", "4", "5", "6", "7", "8"]).hash ==
        hash(hash(hash("1", "2"), hash("3", "4")), hash(hash("5", "6"), hash("7", "8"))) )

assert(newMerkle(["1", "2", "3"]).hash == hash(hash("1", "2"), hash("3", "3")) )

block:
    var m = newMerkle(["naughty"])
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

echo "Finished the lib/MerkleTree test."
