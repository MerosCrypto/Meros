#Base 32 Test.

#Util lib.
import ../../src/lib/Util

#Base 32 lib.
import ../../src/lib/Base32

#Random standard lib.
import random

#Set the seed to be based on the time.
randomize(int(getTime()))

#Verify isBase32.
assert("qpzry9x8gf2tvdw0s3jn54khce6mua7l".isBase32(), "Base 32 rejected valid input.")
assert(not "0ob".isBase32(), "Base 32 accepted invalid input.")
assert(not "@&*(])".isBase32(), "Base 32 accepted invalid input.")

for i in 1 .. 20:
    echo "Testing Base32 encoding/decoding, iteration " & $i & "."

    #Seq of random bytes.
    var byteSeq: seq[uint8] = newSeq[uint8](rand(20))
    for b in 0 ..< byteSeq.len:
        byteSeq[b] = uint8(rand(255))

    #Base32 object.
    var base32: Base32 = byteSeq.toBase32()

    var
        #Base 32 string.
        base32String: string = $base32
        #Array -> Base32 -> Seq
        base32Seq: seq[uint8] = base32.toSeq()

    #Verify the seq.
    assert(byteSeq.len == base32Seq.len, "Base 32 seq's length didn't match the array's length.")
    for b in 0 ..< byteSeq.len:
        assert(byteSeq[b] == base32Seq[b], "Base 32 seq didn't match the array.")

    #Verify parsing strings works.
    assert(base32String == $base32String.toBase32(), "Base 32's parsed data doesn't match the data input.")

echo "Finished the lib/Base32 Test."
