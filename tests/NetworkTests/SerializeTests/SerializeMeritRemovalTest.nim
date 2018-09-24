#Serialize MeritRemoval Test.

#Numerical libs.
import BN
import ../../../src/lib/Base

#Random lib.
import ../../../src/lib/RandomWrapper

#Hash lib.
import ../../../src/lib/Hash

#Wallet lib.
import ../../../src/Wallet/Wallet

#Node object and the MeritRemoval lib.
import ../../../src/Database/Lattice/objects/NodeObj
import ../../../src/Database/Lattice/MeritRemoval

#Serialize lib.
import ../../../src/Network/Serialize/SerializeMeritRemoval
import ../../../src/Network/Serialize/ParseMeritRemoval

#String utils standard lib.
import strutils

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing MeritRemoval Serialization/Parsing, iteration " & $i & "."

    var
        #Wallet.
        wallet: Wallet = newWallet()
        #RHashes.
        first: Hash[512]
        second: Hash[512]
    #Set the hashes with random values.
    random(cast[ptr array[0, uint8]](addr first), 64)
    random(cast[ptr array[0, uint8]](addr second), 64)
    #MeritRemoval.
    var mr: MeritRemoval = newMeritRemoval(
        first,
        second,
        newBN()
    )
    #Sign it.
    wallet.sign(mr)

    #Serialize it and parse it back.
    var mrParsed: MeritRemoval = mr.serialize().parseMeritRemoval()

    #Test the serialized versions.
    assert(mr.serialize() == mrParsed.serialize())

    #Test the Node properties.
    assert(mr.descendant == mrParsed.descendant)
    assert(mr.sender == mrParsed.sender)
    assert(mr.nonce == mrParsed.nonce)
    assert(mr.hash == mrParsed.hash)
    assert(mr.signature == mrParsed.signature)

    #Test the MeritRemoval properties.
    assert(mr.first == mrParsed.first)
    assert(mr.second == mrParsed.second)

echo "Finished the Network/Serialize/MeritRemoval test."
