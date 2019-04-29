#Hex Test.

#Hex lib.
import ../../src/lib/Hex

#Test basic conversions.
assert("17" == $("11".toBNFromHex()), "Basic Hex conversion failed.")
assert("240" == $("F0".toBNFromHex()), "Basic Hex conversion failed.")
assert("255" == $("FF".toBNFromHex()), "Basic Hex conversion failed.")

#Test all hex letters are allowed.
assert("1234567890ABCDEFabcdefABCDEF".isHex(), "Some hex letters weren't allowed.")

#Test non-hex letters aren't allowed.
assert(not "0z".isHex(), "Z was allowed as a hex letter.")

#Verify the output is padded properly.
assert(newBN("0").toHex().len == 2, "0 wasn't prefixed to the Hex string.")

echo "Finished the lib/Base/Base16 Test."
