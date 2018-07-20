import BaseTests/Base16Test
import BaseTests/Base58Test

var res: string

res = Base16test.suite()
if res == "":
    echo "Success."
else:
    echo res

res = Base58Test.suite()
if res == "":
    echo "Success."
else:
    echo res
