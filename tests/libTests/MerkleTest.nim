#Merkle Tree Test.

#Util lib.
import ../../src/lib/Util

#Hash lib.
import ../../src/lib/Hash

#Base lib.
import ../../src/lib/Base

#Merkle lib.
import ../../src/lib/Merkle

block:
    let
        #First leaf.
        a: string = Blake512("a").toString()
        #Second leaf.
        b: string = Blake512("b").toString()
        #Third leaf.
        c: string = Blake512("c").toString()

        #First hash.
        ab: string = Blake512(
            a & b
        ).toString()
        #Second hash.
        cc: string = Blake512(
            c & c
        ).toString()
        #Root hash.
        hash: string = Blake512(
            ab & cc
        ).toString()

    #Create the Merkle Tree.
    var merkle: Merkle = newMerkle(a, b, c)

    #Test the results.
    assert(hash == merkle.hash, "Merkle hash is not what it should be.")

    #Test nil Merle trees.
    assert(newMerkle().hash == "".pad(64))

    #Test adding hashes.
    merkle = newMerkle(a)
    merkle.add(b)
    merkle.add(c)
    assert(merkle.hash == hash)

    merkle = newMerkle()
    merkle.add(a)
    merkle.add(b)
    merkle.add(c)
    assert(merkle.hash == hash)

block:
    let
        #Left-side leaves.
        a: string = Blake512("a").toString()
        b: string = Blake512("b").toString()
        c: string = Blake512("c").toString()
        d: string = Blake512("d").toString()

        #Right-side leaves.
        e: string = Blake512("e").toString()
        f: string = Blake512("f").toString()
        g: string = Blake512("g").toString()
        h: string = Blake512("h").toString()

        #Left-side branches.
        ab: string = Blake512(a & b).toString()
        cd: string = Blake512(c & d).toString()
        abcd: string = Blake512(ab & cd).toString()

        #Right-side branches.
        ef: string = Blake512(e & f).toString()
        gh: string = Blake512(g & h).toString()
        efgh: string  = Blake512(ef & gh).toString()

        #Changed branched if we remove h.
        gg: string = Blake512(g & g).toString()
        efgg: string = Blake512(ef & gg).toString()
        abcdefgg: string = Blake512(abcd & efgg).toString()

        #Changed branches if we remove g and h.
        efef: string = Blake512(ef & ef).toString()
        abcdefef: string = Blake512(abcd & efef).toString()

        #Changed branches if we remove d, e, f, g, and h.
        cc: string = Blake512(c & c).toString()
        abcc: string = Blake512(ab & cc).toString()

        #Tree hashes.
        abcdefgh: string = Blake512(abcd & efgh).toString()

        #Create the merkle trees.
        merkle_ah: Merkle = newMerkle(a, b, c, d, e, f, g, h)
        merkle_ah2: Merkle = merkle_ah.trim(0)
        merkle_ag: Merkle = merkle_ah.trim(1)
        merkle_af: Merkle = merkle_ah.trim(2)
        merkle_ac: Merkle = merkle_ah.trim(5)

    #Verify the merkle_ah and merkle_ah2 hashes.
    assert(merkle_ah.hash == abcdefgh)
    assert(merkle_ah2.hash == merkle_ah.hash)

    #Verify merkle_ah2's ref is the same as merkle_ah.
    assert(cast[int](merkle_ah2) == cast[int](merkle_ah))

    #Verify the merkle_ag hash and refs.
    assert(merkle_ag.hash == abcdefgg)
    assert(merkle_ag.left == merkle_ah.left)
    assert(merkle_ag.right != merkle_ah.right)

    #Verify the merkle_af hash and refs.
    assert(merkle_af.hash == abcdefef)
    assert(merkle_af.left == merkle_ah.left)
    assert(merkle_af.right != merkle_ah.right)

    #Verify the merkle_ac hash and refs.
    assert(merkle_ac.hash == abcc)
    assert(merkle_ac.left != merkle_ah.left)
    assert(merkle_ac.right != merkle_ah.right)
    assert(merkle_ac.left == merkle_ah.left.left)
    assert(merkle_ac.left != merkle_ah.left.right)

echo "Finished the lib/Merkle Test."
