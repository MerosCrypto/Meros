#Base 32 Test.

#Base 32 Test.
import ../../src/lib/Base32

#Verify isBase32.
assert("qpzry9x8gf2tvdw0s3jn54khce6mua7l".isBase32(), "Base 32 rejected valid input.")
assert(not "0ob".isBase32(), "Base 32 accepted invalid input.")
assert(not "@&*(])".isBase32(), "Base 32 accepted invalid input.")

var
    #Array with test values.
    byteArray: array[5, uint8] = [
        uint8(10),
        uint8(20),
        uint8(30),
        uint8(40),
        uint8(50)
    ]
    #Base32 object.
    base32: Base32 = byteArray.toBase32()
    #Base 32 string.
    base32String: string = $base32
    #Array -> Base32 -> Seq
    base32Seq: seq[uint8] = base32.toSeq()

#Verify the string.
assert(base32String == "pg2pu2pj", "Base 32 string isn't what it should be.")

#Verify the seq.
assert(byteArray.len == base32Seq.len, "Base 32 seq's length didn't match the array's length.")
for i in 0 ..< byteArray.len:
    assert(byteArray[i] == base32Seq[i], "Base 32 seq didn't match the array.")

#Verify parsing strings works.
assert(base32String == $base32String.toBase32(), "Base 32's parsed data doesn't match the data input.")

echo "Finished the lib/Base32 test."
