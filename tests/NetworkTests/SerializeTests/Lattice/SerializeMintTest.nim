#Serialize Mint Test.

#Util lib.
import ../../../../src/lib/Util

#Numerical libs.
import BN
import ../../../../src/lib/Base

#Hash lib.
import ../../../../src/lib/Hash

#BLS lib.
import ../../../../src/lib/BLS

#Entry object and the Mint lib.
import ../../../../src/Database/Lattice/objects/EntryObj
import ../../../../src/Database/Lattice/Mint

#Serialize libs.
import ../../../../src/Network/Serialize/Lattice/SerializeMint
import ../../../../src/Network/Serialize/Lattice/ParseMint

#Random standard lib.
import random

#Seed Random via the time.
randomize(int(getTime()))

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing Mint Serialization/Parsing, iteration " & $i & "."

    #Mint (for a random amount).
    var mint: Mint = newMint(
        newBLSPrivateKeyFromSeed(rand(150000).toBinary()).getPublicKey().toString(),
        newBN(rand(100000000)),
        uint(rand(75000))
    )

    #Serialize it and parse it back.
    var mintParsed: Mint = mint.serialize().parseMint()

    #Test the serialized versions.
    assert(mint.serialize() == mintParsed.serialize())

    #Test the Entry properties.
    assert(mint.descendant == mintParsed.descendant)
    assert(mint.sender == mintParsed.sender)
    assert(mint.nonce == mintParsed.nonce)
    assert(mint.hash == mintParsed.hash)
    assert(mint.signature == mintParsed.signature)
    assert(mint.verified == mintParsed.verified)

    #Test the Mint properties.
    assert(mint.output == mintParsed.output)
    assert(mint.amount == mintParsed.amount)

echo "Finished the Network/Serialize/Lattice/Mint Test."
