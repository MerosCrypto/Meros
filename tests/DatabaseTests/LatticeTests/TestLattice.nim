#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Lattice lib.
import ../../../src/Database/Lattice/Lattice

#Tables lib.
import tables

proc compare*(
    e1: Entry,
    e2: Entry
) =
    #Test the Entry fields.
    assert(e1.descendant == e2.descendant)
    assert(e1.sender == e2.sender)
    assert(e1.nonce == e2.nonce)
    assert(e1.hash == e2.hash)
    assert(e1.signature == e2.signature)
    assert(e1.verified == e2.verified)

    #Test the sub-type fields.
    case e1.descendant:
        of EntryType.Mint:
            assert(cast[Mint](e1).output == cast[Mint](e2).output)
            assert(cast[Mint](e1).amount == cast[Mint](e2).amount)
        of EntryType.Claim:
            assert(cast[Claim](e1).mintNonce == cast[Claim](e2).mintNonce)
            assert(cast[Claim](e1).bls == cast[Claim](e2).bls)
        of EntryType.Send:
            assert(cast[Send](e1).output == cast[Send](e2).output)
            assert(cast[Send](e1).amount == cast[Send](e2).amount)
            assert(cast[Send](e1).proof == cast[Send](e2).proof)
            assert(cast[Send](e1).argon == cast[Send](e2).argon)
        of EntryType.Receive:
            assert(cast[Receive](e1).input.address == cast[Receive](e2).input.address)
            assert(cast[Receive](e1).input.nonce == cast[Receive](e2).input.nonce)
        of EntryType.Data:
            assert(cast[Data](e1).data == cast[Data](e2).data)
            assert(cast[Data](e1).proof == cast[Data](e2).proof)
            assert(cast[Data](e1).argon == cast[Data](e2).argon)

proc compare*(
    a1: Account,
    a2: Account
) =
    #Test they have the same address.
    assert(a1.address == a2.address)

    #Make sure the lookup was set to nil.
    assert(a1.lookup.isNil)
    assert(a2.lookup.isNil)

    #Test they have the same balance.
    assert(a1.balance == a2.balance)

    #Test they have the same height/confirmed.
    assert(a1.height == a2.height)
    assert(a1.confirmed == a2.confirmed)

    #Test the Entries, as well as the claimable table.
    assert(a1.entries.len == a2.entries.len)

    assert(a1.claimableStr == a2.claimableStr)
    assert(a1.claimable.len == a2.claimable.len)
    for key in a1.claimable.keys():
        assert(a2.claimable.hasKey(key))

    #Test the potential debt.
    assert(a1.potentialDebt == a2.potentialDebt)

    #Check every Entry.
    for e in 0 ..< a1.height:
        var
            a1Entries: seq[Entry]
            a2Entries: seq[Entry]

        if e < a1.confirmed:
            a1Entries = @[a1[e]]
            a2Entries = @[a2[e]]
        else:
            a1Entries = a1.entries[e - a2.confirmed]
            a2Entries = a2.entries[e - a2.confirmed]

        for e in 0 ..< a1Entries.len:
            compare(a1Entries[e], a2Entries[e])

proc compare*(
    l1: var Lattice,
    l2: var Lattice
) =
    #Test the lookup table.
    assert(l1.lookup.len == l2.lookup.len)
    for hash in l1.lookup.keys():
        assert(l2.lookup.hasKey(hash))
        assert(l1.lookup[hash].address == l2.lookup[hash].address)
        assert(l1.lookup[hash].nonce == l2.lookup[hash].nonce)

    #Test the verifications tables.
    assert(l1.verifications.len == l2.verifications.len)
    for hash in l1.verifications.keys():
        assert(l2.verifications.hasKey(hash))
        assert(l1.verifications[hash].len == l2.verifications[hash].len)
        for holder in l1.verifications[hash]:
            assert(l2.verifications[hash].contains(holder))

    #Test the weights tables.
    assert(l1.weights.len == l2.weights.len)
    for hash in l1.weights.keys():
        assert(l2.weights.hasKey(hash))
        assert(l1.weights[hash] == l2.weights[hash])

    #Test each account.
    assert(l1.accounts.len == l2.accounts.len)
    for address in l1.accounts.keys():
        assert(l2.accounts.hasKey(address))
        compare(l1[address], l2[address])
