#SHA3 Test.

#Fuzzing lib.
import ../../Fuzzed

#Hash lib.
import ../../../src/lib/Hash

suite "SHA3":
    noFuzzTest "`` vector on 256.":
        check(
            $SHA3_256("") == "A7FFC6F8BF1ED76651C14756A061D662F580FF4DE43B49FA82D80A4B80F8434A"
        )

    noFuzzTest "`abc` vector on 256.":
        check(
            $SHA3_256("abc") == "3A985DA74FE225B2045C172D6BD390BD855F086E3E9D525B46BFE24511431532"
        )
