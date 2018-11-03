#Serialize MeritRemoval Test.

#Hash lib.
import ../../../../src/lib/Hash

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Entry object and the MeritRemoval lib.
import ../../../../src/Database/Lattice/objects/EntryObj
import ../../../../src/Database/Lattice/MeritRemoval

#Serialize lib.
import ../../../../src/Network/Serialize/Lattice/SerializeMeritRemoval
import ../../../../src/Network/Serialize/Lattice/ParseMeritRemoval

#Random standard lib.
import random

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
    for i in 0 ..< 64:
        first.data[i] = uint8(rand(255))
    #Set the hashes with random values.
    for i in 0 ..< 64:
        second.data[i] = uint8(rand(255))

    #MeritRemoval.
    var mr: MeritRemoval = newMeritRemoval(
        first,
        second,
        0
    )
    #Sign it.
    wallet.sign(mr)

    #Serialize it and parse it back.
    var mrParsed: MeritRemoval = mr.serialize().parseMeritRemoval()

    #Test the serialized versions.
    assert(mr.serialize() == mrParsed.serialize())

    #Test the Entry properties.
    assert(mr.descendant == mrParsed.descendant)
    assert(mr.sender == mrParsed.sender)
    assert(mr.nonce == mrParsed.nonce)
    assert(mr.hash == mrParsed.hash)
    assert(mr.signature == mrParsed.signature)

    #Test the MeritRemoval properties.
    assert(mr.first == mrParsed.first)
    assert(mr.second == mrParsed.second)

echo "Finished the Network/Serialize/Lattice/MeritRemoval test."
