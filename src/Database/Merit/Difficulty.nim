import algorithm

import stint

import ../../lib/[Errors, Util]
import algorithm

proc calculateWindowLength*(
  height: int
): int {.forceCheck: [].} =
  #If we're in the first 5 Blocks, the difficulty is fixed.
  if height < 6:
    result = 0
  #If we're in the first month, the window length is 5 Blocks (just under 1 hour).
  elif height < 4320:
    result = 5
  #If we're in the first three months, the window length is 9 Blocks (1.5 hours).
  elif height < 12960:
    result = 9
  #If we're in the first six months, the window length is 18 Blocks (3 hours).
  elif height < 25920:
    result = 18
  #If we're in the first year, the window length is 36 Blocks (6 hours).
  elif height < 52560:
    result = 36
  #Else, if it's over an year, the window length is 72 Blocks (12 hours).
  else:
    result = 72

proc calculateNextDifficulty*(
  blockTime: StUInt[128],
  windowLength: int,
  difficultiesArg: seq[uint64],
  time: uint32
): uint64 {.forceCheck: [].} =
  if windowLength == 0:
    return difficultiesArg[0]

  var
    difficulties: seq[uint64]
    median: uint64

  #Grab the difficulties.
  #We exclude the first difficulty as its PoW was created before the indicated time.
  difficulties = difficultiesArg[difficultiesArg.len - (windowLength - 1) ..< difficultiesArg.len]

  #Sort the difficulties.
  difficulties.sort()
  #Grab the median difficulty.
  median = difficulties[windowLength div 2]
  #Remove outlying difficulties.
  for _ in 0 ..< windowLength div 10:
    if (difficulties[^1] - median) > (median - difficulties[0]):
      difficulties.del(high(difficulties))
    else:
      difficulties.delete(0)

  #Calculate the new difficulty.
  var newDifficulty: StUInt[128]
  for diff in difficulties:
    newDifficulty += stuint(diff, 128)
  newDifficulty = newDifficulty * blockTime
  try:
    newDifficulty = newDifficulty div stuint(time, 128)
  except DivByZeroError:
    panic("DivByZeroError when dividing by " & $time & ".")

  #Convert it from an StUInt[128] to an uint64.
  result = max(
    uint64(cast[string](newDifficulty.toBytesLE()[0 ..< 8]).fromBinary()),
    uint64(1)
  )
