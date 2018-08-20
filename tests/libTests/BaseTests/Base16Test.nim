#Base16 Test.
#Numerical libs.
import ../../../src/lib/BN
import ../../../src/lib/Base

#Test basic conversions.
assert("17" == "11".toBN(16).toString(10), "Basic Hex conversion failed.")
assert("240" == "F0".toBN(16).toString(10), "Basic Hex conversion failed.")
assert("255" == "FF".toBN(16).toString(10), "Basic Hex conversion failed.")

#Test all hex letters are allowed.
assert("1234567890ABCDEFabcdef".isBase(16), "Some hex letters weren't allowed.")

#Test non-hex letters aren't allowed.
assert("0z".isBase(16) == false, "Z was allowed as a hex letter.")

#Verify the output is padded properly.
assert("0".toBN(10).toString(16).len == 2, "0 wasn't prefixed to the Hex string.")

echo "Finished the lib/Base/Base16 test."
