import BN
import ../src/Ember/lib/base

assert("1234567898765432234567".isBase(10))
assert(not "0001012".isBase(2))

assert(newBN(5) == "101".toBN(2))
assert(newBN(15) == "F".toBN(26))

assert("F" == newBN(15).toString(26))
assert("9A7E0C" == newBN(10124812).toString(16))
assert("10" == newBN(10).toString(10))
