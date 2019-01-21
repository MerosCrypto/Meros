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
    let
        ee = SHA512(e & e).toString()
        eeee = SHA512(ee & ee).toString()
        abcdeeee = SHA512(abcd & eeee).toString()
        tree_ae = newMerkle(a, b, c, d, e)
    assert(tree_ae.hash == abcdeeee)

    #now, a-f
    let
        ef = SHA512(e & f).toString()
        efef = SHA512(ef & ef).toString()
        abcdefef = SHA512(abcd & efef).toString()
        #not just ANY tree
        #this one is tree as FUCK
        tree_af = newMerkle(a, b, c, d, e, f)
    assert(tree_af.hash == abcdefef)

    #now, a-g
    let
        gg = SHA512(g & g).toString()
        efgg = SHA512(ef & gg).toString()
        abcdefgg = SHA512(abcd & efgg).toString()
        tree_ag = newMerkle(a, b, c, d, e, f, g)
    assert(tree_ag.hash == abcdefgg)

    #finally, a-h
    let
        gh = SHA512(g & h).toString()
        efgh = SHA512(ef & gh).toString()
        abcdefgh = SHA512(abcd & efgh).toString()
        tree_ah = newMerkle(a, b, c, d, e, f, g, h)
    assert(tree_ah.hash == abcdefgh)


    #test leaf removal
    let tree_ad = newMerkle(abcd)
    let abcc = SHA512(ab & SHA512(c & c).toString()).toString()

    assert(tree_ah.withoutNLeaves(7).hash == a)
    assert(tree_ah.withoutNLeaves(6).hash == ab)
    assert(tree_ah.withoutNLeaves(5).hash == abcc)
    assert(tree_ah.withoutNLeaves(4).hash == tree_ad.hash)
    assert(tree_ah.withoutNLeaves(3).hash == tree_ae.hash)
    assert(tree_ah.withoutNLeaves(2).hash == tree_af.hash)
    assert(tree_ah.withoutNLeaves(1).hash == tree_ag.hash)
    assert(tree_ah.withoutNLeaves(0).hash == tree_ah.hash)

    assert(tree_ag.withoutNLeaves(6).hash == a)
    assert(tree_ag.withoutNLeaves(5).hash == ab)
    assert(tree_ag.withoutNLeaves(4).hash == abcc)
    assert(tree_ag.withoutNLeaves(3).hash == tree_ad.hash)
    assert(tree_ag.withoutNLeaves(2).hash == tree_ae.hash)
    assert(tree_ag.withoutNLeaves(1).hash == tree_af.hash)
    assert(tree_ag.withoutNLeaves(0).hash == tree_ag.hash)

    assert(tree_af.withoutNLeaves(5).hash == a)
    assert(tree_af.withoutNLeaves(4).hash == ab)
    assert(tree_af.withoutNLeaves(3).hash == abcc)
    assert(tree_af.withoutNLeaves(2).hash == tree_ad.hash)
    assert(tree_af.withoutNLeaves(1).hash == tree_ae.hash)
    assert(tree_af.withoutNLeaves(0).hash == tree_af.hash)

    assert(tree_ae.withoutNLeaves(4).hash == a)
    assert(tree_ae.withoutNLeaves(3).hash == ab)
    assert(tree_ae.withoutNLeaves(2).hash == abcc)
    assert(tree_ae.withoutNLeaves(1).hash == tree_ad.hash)
    assert(tree_ae.withoutNLeaves(0).hash == tree_ae.hash)

echo "Finished the lib/Merkle test."
