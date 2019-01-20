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
    var
        #First leaf.
        a: string = SHA512("a").toString()
        #Second leaf.
        b: string = SHA512("b").toString()
        #Third leaf.
        c: string = SHA512("c").toString()

        #First hash.
        ab: string = SHA512(
            a & b
        ).toString()
        #Second hash.
        cc: string = SHA512(
            c & c
        ).toString()
        #Root hash.
        hash: string = SHA512(
            ab & cc
        ).toString()

        #Create the Merkle Tree.
        merkle: Merkle = newMerkle(a, b, c)

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
        a = SHA512("a").toString()
        b = SHA512("b").toString()
        c = SHA512("c").toString()
        d = SHA512("d").toString()

        e = SHA512("e").toString()
        f = SHA512("f").toString()
        g = SHA512("g").toString()
        h = SHA512("h").toString()

        #will test trees comprised of a-e, a-f, a-g, and a-h

        ab = SHA512(a & b).toString()
        cd = SHA512(c & d).toString()
        abcd = SHA512(ab & cd).toString()

    #first, a-e
    block:
        let
            ee = SHA512(e & e).toString()
            eeee = SHA512(ee & ee).toString()
            abcdeeee = SHA512(abcd & eeee).toString()
            tree = newMerkle(a, b, c, d, e)
        assert(tree.hash == abcdeeee)

    #now, a-f
    block:
        let
            ef = SHA512(e & f).toString()
            efef = SHA512(ef & ef).toString()
            abcdefef = SHA512(abcd & efef).toString()
            tree = newMerkle(a, b, c, d, e, f)
        assert(tree.hash == abcdefef)

    #now, a-g
    block:
        let
            ef = SHA512(e & f).toString()
            gg = SHA512(g & g).toString()
            efgg = SHA512(ef & gg).toString()
            abcdefgg = SHA512(abcd & efgg).toString()
            tree = newMerkle(a, b, c, d, e, f, g)
        assert(tree.hash == abcdefgg)

    #finally, a-h
    block:
        let
            ef = SHA512(e & f).toString()
            gh = SHA512(g & h).toString()
            efgh = SHA512(ef & gh).toString()
            abcdefgh = SHA512(abcd & efgh).toString()
            tree = newMerkle(a, b, c, d, e, f, g, h)
        assert(tree.hash == abcdefgh)



echo "Finished the lib/Merkle test."
