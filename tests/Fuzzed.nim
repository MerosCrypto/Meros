import random
import unittest
export suite, suiteStarted, TestStatus, TestResult, testStarted, checkpoint, check, fail, expect

import ../src/lib/[Util, Hash]

const TEST_FUZZING_LOW  {.intdefine.}: int = 1
const TEST_FUZZING_MID  {.intdefine.}: int = 4
const TEST_FUZZING_HIGH {.intdefine.}: int = 8

#Create a random hash.
#Placed here as a lot of tests need this and every test imports this.
proc newRandomHash*(): Hash[256] =
  for b in 0 ..< 32:
    result.data[b] = byte(rand(255))

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
