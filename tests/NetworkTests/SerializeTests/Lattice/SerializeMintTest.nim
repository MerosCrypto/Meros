#Serialize Mint Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#BLS lib.
import ../../../../src/Wallet/MinerWallet

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Entry object.
import ../../../../src/Database/Lattice/objects/EntryObj

#Mint lib.
import ../../../../src/Database/Lattice/Mint

#Serialization libs.
import ../../../../src/Network/Serialize/Lattice/SerializeMint
import ../../../../src/Network/Serialize/Lattice/ParseMint

#Random standard lib.
import random

#Seed Random via the time.
randomize(getTime())

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing Mint Serialization/Parsing, iteration " & $i & "."

    #Mint (for a random amount).
    var mint: Mint = newMint(
        newBLSPrivateKeyFromSeed(rand(150000).toBinary()).getPublicKey(),
        uint64(rand(100000000)),
        rand(75000)
    )

    #Serialize it and parse it back.
    var mintParsed: Mint = mint.serialize(false).parseMint()

    #Test the serialized versions.
    assert(mint.serialize(false) == mintParsed.serialize(false))

    #Test the Entry properties.
    assert(mint.descendant == mintParsed.descendant)
    assert(mint.sender == mintParsed.sender)
    assert(mint.nonce == mintParsed.nonce)
    assert(mint.hash == mintParsed.hash)
    assert(mint.signature.toString() == mintParsed.signature.toString())
    assert(mint.verified == mintParsed.verified)

    #Test the Mint properties.
    assert(mint.output == mintParsed.output)
    assert(mint.amount == mintParsed.amount)

echo "Finished the Network/Serialize/Lattice/Mint Test."
