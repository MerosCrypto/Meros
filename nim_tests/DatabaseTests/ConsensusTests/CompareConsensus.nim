#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Consensus lib.
import ../../../src/Database/Consensus/Consensus

#Compare two Verifications to make sure they have the same value.
proc compare*(
    e1: Element,
    e2: Element
) =
    #Test the Element fields.
    assert(e1.holder == e2.holder)
    assert(e1.nonce == e2.nonce)

    #Test the descendant fields.
    if (e1 of Verification) and (e2 of Verification):
        assert(cast[Verification](e1).hash == cast[Verification](e2).hash)
    else:
        assert(false)

#Compare two MeritHolders to make sure they have the same value.
proc compare*(
    mh1: MeritHolder,
    mh2: MeritHolder
) =
    #Test both have the same fields.
    assert(mh1.key == mh2.key)
    assert(mh1.archived == mh2.archived)
    assert(mh1.merkle.hash == mh2.merkle.hash)

    #Test the Elements.
    for i in 0 .. mh1.archived:
        compare(mh1[i], mh2[i])

#Compare two Consensuses to make sure they have the same value.
proc compare*(
    c1: Consensus,
    c2: Consensus
) =
    #Get the holders.
    var
        c1Holders: seq[BLSPublicKey] = @[]
        c2Holders: seq[BLSPublicKey] = @[]
    for holder in c1.holders:
        c1Holders.add(holder)
    for holder in c2.holders:
        c2Holders.add(holder)

    #Compare the holders.
    assert(c1Holders.len == c2Holders.len)
    for holder in c1Holders:
        assert(c2Holders.contains(holder))
        compare(c1[holder], c2[holder])
