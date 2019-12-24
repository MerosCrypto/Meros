#SHA2 Tests.

#Test lib.
import unittest2

#Hash lib.
import ../../../src/lib/Hash

suite "SHA2":
    test "`` vector on 256.":
        assert(
            $SHA2_256("") == "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"
        )

    test "`abc` vector on 256.":
        assert(
            $SHA2_256("abc") == "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"
        )
