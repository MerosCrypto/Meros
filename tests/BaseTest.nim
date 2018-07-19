import BN
import ../src/lib/Base

assert("1234567898765432234567".isBase(10))
assert(not "0001012".isBase(2))

assert(newBN(5) == "101".toBN(2))
assert(newBN(15) == "G".toBN(26))

assert("G" == newBN(15).toString(26))
assert("9A7E0C" == newBN(10124812).toString(16))
assert("10" == newBN(10).toString(10))

assert(newBN(0) == "1".toBN(58))
assert(newBN(8) == "9".toBN(58))
assert(newBN(57) == "z".toBN(58))
assert(newBN(59) == "22".toBN(58))
assert(newBN(3364) == "211".toBN(58))
assert(newBN(3369) == "216".toBN(58))

assert(newBN(0).toString(58) == "1")
assert(newBN(8).toString(58) == "9")
assert(newBN(57).toString(58) == "z")
assert(newBN(59).toString(58) == "22")
assert(newBN(3364).toString(58) == "211")
assert(newBN(3369).toString(58) == "216")
