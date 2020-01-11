#Keccak Test.

#Test lib.
import unittest

#Hash lib.
import ../../../src/lib/Hash

suite "KeccakTest":
    test "`` vector on 256.":
        check(
            $Keccak_256("") == "C5D2460186F7233C927E7DB2DCC703C0E500B653CA82273B7BFAD8045D85A470"
        )

    test "`abc` vector on 256.":
        check(
            $Keccak_256("abc") == "4E03657AEA45A94FC7D47BA826C8D667C0D1E6E33A64A036EC44F58FA12D6C45"
        )
