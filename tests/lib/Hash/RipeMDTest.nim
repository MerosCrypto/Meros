#RipeMD Test.

#Fuzzing lib.
import ../../Fuzzed

#Hash lib.
import ../../../src/lib/Hash

suite "RipeMD":
  noFuzzTest "`` vector on 160.":
    check(
      $RipeMD_160("") == "9C1185A5C5E9FC54612808977EE8F548B2258D31"
    )

  noFuzzTest "`abc` vector on 160.":
    check(
      $RipeMD_160("abc") == "8EB208F7E05D987A9B044A8E98C6B087F15A0BFC"
    )
