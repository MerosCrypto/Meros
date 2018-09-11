#Base 58 Test.

#Numerical libs.
import BN
import ../../../src/lib/Base

#Test basic conversions.
assert("58" == "21".toBN(58).toString(10), "Basic Base58 conversion failed.")
assert("59" == "22".toBN(58).toString(10), "Basic Base58 conversion failed.")
assert("131" == "3G".toBN(58).toString(10), "Basic Base58 conversion failed.")

#Test all Base58 letters are allowed.
assert("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".isBase(58), "Some Base58 letters weren't allowed.")

#Test non-Base58 letters aren't allowed.
assert(not "O".isBase(58), "O (Oh) was allowed as a hex letter.")

echo "Finished the lib/Base/Base58 test."
