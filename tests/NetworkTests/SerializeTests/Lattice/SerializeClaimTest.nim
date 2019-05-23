#Serialize Claim Tests.

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Entry object.
import ../../../../src/Database/Lattice/objects/EntryObj

#Claim lib.
import ../../../../src/Database/Lattice/Claim

#Serialization libs.
import ../../../../src/Network/Serialize/Lattice/SerializeClaim
import ../../../../src/Network/Serialize/Lattice/ParseClaim

import strutils

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing Claim Serialization/Parsing, iteration " & $i & "."

    var
        #People.
        miner: MinerWallet = newMinerWallet()
        claimer: Wallet = newWallet()
        #Claim.
        claim: Claim

    #Create the Claim.
    claim = newClaim(
        0,
        0
    )

    #Sign it.
    claim.sign(miner, claimer)

    #Serialize it and parse it back.
    var claimParsed: Claim = claim.serialize().parseClaim()

    #Test the serialized versions.
    assert(claim.serialize() == claimParsed.serialize())

    #Test the Entry properties.
    assert(claim.descendant == claimParsed.descendant)
    assert(claim.sender == claimParsed.sender)
    assert(claim.nonce == claimParsed.nonce)
    assert(claim.hash == claimParsed.hash)
    assert(claim.signature.toString() == claimParsed.signature.toString())
    assert(claim.verified == claimParsed.verified)

    #Test the Claim properties.
    assert(claim.mintNonce == claimParsed.mintNonce)
    assert(claim.bls == claimParsed.bls)

echo "Finished the Network/Serialize/Lattice/Claim Test."
