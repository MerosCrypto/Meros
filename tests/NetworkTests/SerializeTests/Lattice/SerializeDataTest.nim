#Serialize Data Test.

#Util lib.
import ../../../../src/lib/Util

#BN/Hex lib.
import ../../../../src/lib/Hex

#Hash lib.
import ../../../../src/lib/Hash

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Entry object.
import ../../../../src/Database/Lattice/objects/EntryObj

#Data lib.
import ../../../../src/Database/Lattice/Data

#Serialization libs.
import ../../../../src/Network/Serialize/Lattice/SerializeData
import ../../../../src/Network/Serialize/Lattice/ParseData

#Test data.
var tests: seq[string] = @[
    "",
    "123",
    "abc",
    "abcdefghijklmnopqrstuvwxyz",
    "Test",
    "Test1",
    "Test2",
    "This is a longer Test.",
    "Now we have special character.\r\n",
    "\0\0This Test starts with leading 0s and is meant to Test Issue #46.",
    "Write the tests they said.",
    "Make up phrases they said.",
    "Well here are the phrases.",
    "#^&^%^&*",
    "Phrase.",
    "Another phrase.",
    "Yet another phrase.",
    "This is 32 characters long.     ",
    "".pad(8, " This is 255 characters long.   ").substr(1),
    "This is the 20th Test because I wanted a nice number."
]

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing Data Serialization/Parsing, iteration " & $i & "."

    var
        #Wallet.
        wallet: Wallet = newWallet()
        #Data.
        data: Data = newData(
            tests[i - 1],
            0
        )

    #Sign it.
    wallet.sign(data)
    #Mine the Data.
    data.mine("3333333333333333333333333333333333333333333333333333333333333333".toBNFromHex())

    #Serialize it and parse it back.
    var dataParsed: Data = data.serialize().parseData()

    #Test the serialized versions.
    assert(data.serialize() == dataParsed.serialize())

    #Test the Entry properties.
    assert(data.descendant == dataParsed.descendant)
    assert(data.sender == dataParsed.sender)
    assert(data.nonce == dataParsed.nonce)
    assert(data.hash == dataParsed.hash)
    assert(data.signature.toString() == dataParsed.signature.toString())
    assert(data.verified == dataParsed.verified)

    #Test the Data properties.
    assert(data.data == dataParsed.data)
    assert(data.proof == dataParsed.proof)
    assert(data.argon == dataParsed.argon)

echo "Finished the Network/Serialize/Lattice/Data Test."
