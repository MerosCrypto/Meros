#Base 32 Test.

#Util lib.
import ../../src/lib/Util

#Base 32 lib.
import ../../src/lib/Base32

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    #Test isBase32.
    var base32: string = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
    for c in 0 .. 255:
        for b in base32:
            if char(c) == b:
                assert(($char(c)).isBase32())
                break

            if b == base32[^1]:
                assert(not ($char(c)).isBase32())

    for i in 0 .. 255:
        #Seq of random bytes.
        var byteSeq: seq[uint8] = newSeq[uint8](rand(i))
        for b in 0 ..< byteSeq.len:
            byteSeq[b] = uint8(rand(255))

        var
            #Base32 object.
            base32: Base32 = byteSeq.toBase32()
            #Reverted Base32 seq.
            base32Seq: seq[uint8] = base32.toSeq()
            #Base 32 string.
            base32String: string = $base32

        #Verify the seq.
        assert(byteSeq.len == base32Seq.len)
        for b in 0 ..< byteSeq.len:
            assert(byteSeq[b] == base32Seq[b])

        #Verify parsing/reserializing the string.
        assert(base32String == $base32String.toBase32())

    echo "Finished the lib/Base32 Test."
