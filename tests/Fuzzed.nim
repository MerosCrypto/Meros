import unittest2

const TEST_FUZZING_LOW {.intdefine.}: int = 1
const TEST_FUZZING_MID {.intdefine.}: int = 4
const TEST_FUZZING_HIGH {.intdefine.}: int = 8

template lowFuzzTest*(
    name: string, 
    body: untyped
) =
    for i in 1 .. TEST_FUZZING_LOW:
        test name & " (" & $i & "/" & $TEST_FUZZING_LOW & ")":
            body

template midFuzzTest*(
    name: string, 
    body: untyped
) =
    for i in 1 .. TEST_FUZZING_MID:
        test name & " (" & $i & "/" & $TEST_FUZZING_MID & ")":
            body

template highFuzzTest*(
    name: string, 
    body: untyped
) =
    for i in 1 .. TEST_FUZZING_HIGH:
        test name & " (" & $i & "/" & $TEST_FUZZING_HIGH & ")":
            body
