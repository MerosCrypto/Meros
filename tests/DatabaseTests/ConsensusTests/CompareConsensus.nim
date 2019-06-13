#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Consensus lib.
import ../../../src/Database/Consensus/Consensus

import ../../../src/Database/Consensus/objects/SendDifficultyObj
import ../../../src/Database/Consensus/objects/VerificationObj
import ../../../src/Database/Consensus/objects/DataDifficultyObj
import ../../../src/Database/Consensus/objects/GasPriceObj
import ../../../src/Database/Consensus/objects/MeritRemovalObj

#Compare two Verifications to make sure they have the same value.
proc compare*(
    v1: Element,
    v2: Element
) =
    #Test the Element fields.
    assert(v1.holder == v2.holder)
    assert(v1.nonce == v2.nonce)

    if v1 of Verification and v2 of Verification:
      assert(cast[Verification](v1).hash == cast[Verification](v2).hash)
    # STUBS!!
    elif v1 of SendDifficulty and v2 of SendDifficulty:
      discard
    elif v1 of DataDifficulty and v2 of DataDifficulty:
      discard
    elif v1 of MeritRemoval and v2 of MeritRemoval:
      discard
    elif v1 of GasPrice and v2 of GasPrice:
      discard
    else:  # types don't match
      assert false

#Compare two Signed Verifications to make sure they have the same value.
proc compare*(
    v1: SignedVerification,
    v2: SignedVerification
) =
    compare(cast[Verification](v1), cast[Verification](v2))
    assert(v1.signature == v2.signature)

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
