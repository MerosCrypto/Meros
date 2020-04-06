#Util lib.
import ../src/lib/Util

#Random standard lib.
import random

#unittest standard lib.
import unittest
#Export the suite and check macros.
export suite, suiteStarted, TestStatus, TestResult, testStarted, checkpoint, check, fail

const TEST_FUZZING_LOW {.intdefine.}: int = 1
const TEST_FUZZING_MID {.intdefine.}: int = 4
const TEST_FUZZING_HIGH {.intdefine.}: int = 8

template setupRandom() =
    var seed: int64 = int64(getTime())
    randomize(seed)
    checkpoint("Randomize Seed: " & $seed)

template noFuzzTest*(
    name: string,
    body: untyped
) =
    test name:
        setupRandom
        body

template lowFuzzTest*(
    name: string,
    body: untyped
) =
    for i in 1 .. TEST_FUZZING_LOW:
        test name & " (" & $i & "/" & $TEST_FUZZING_LOW & ")":
            setupRandom
            body

template midFuzzTest*(
    name: string,
    body: untyped
) =
    for i in 1 .. TEST_FUZZING_MID:
        test name & " (" & $i & "/" & $TEST_FUZZING_MID & ")":
            setupRandom
            body

template highFuzzTest*(
    name: string,
    body: untyped
) =
    for i in 1 .. TEST_FUZZING_HIGH:
        test name & " (" & $i & "/" & $TEST_FUZZING_HIGH & ")":
            setupRandom
            body
