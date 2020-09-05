import sequtils
import strutils
import sets
import tables

import ../../../lib/Errors
import ./TransactionObj

type
  FamilyID = ref object
    #Not a case statement as we need to be able to update this in realtime without re-instantiation
    active: bool
    id: uint64
    merged: FamilyID

  FamilyManager* = ref object
    lastID: uint64
    inputMap: Table[Input, FamilyID]
    families: Table[uint64, HashSet[Input]]

func newFamilyManager*(): FamilyManager {.inline, forceCheck: [].} =
  FamilyManager(
    lastID: 1,
    inputMap: initTable[Input, FamilyID](),
    families: initTable[uint64, HashSet[Input]]()
  )

func resolve(
  id: FamilyID
): FamilyID {.inline, forceCheck: [].} =
  result = id
  while not result.active:
    result = result.merged

proc merge(
  families: FamilyManager,
  targetArg: FamilyID,
  sourceArg: FamilyID
) {.forceCheck: [].} =
  var
    target: FamilyID = targetArg.resolve()
    source: FamilyID = sourceArg.resolve()
  #Forward the source ID to point to the target.
  source.active = false
  source.merged = target
  #Move over the inputs.
  try:
    families.families[target.id] = families.families[target.id] + families.families[source.id]
  except KeyError:
    panic("Merging families when one doesn't exist")
  families.families.del(source.id)

proc register*(
  families: FamilyManager,
  inputs: seq[Input]
) {.forceCheck: [].} =
  var
    family: FamilyID
    temp: FamilyID
  for i in 0 ..< inputs.len:
    try:
      temp = families.inputMap[inputs[i]].resolve()
      if family.isNil:
        family = temp
        continue

      if temp.id != family.id:
        families.merge(family, temp)
    except KeyError:
      if family.isNil:
        family = FamilyID(
          active: true,
          id: families.lastID
        )
        #Shouldn't be needed as uints shouldn't have overflow checks.
        {.push boundChecks: off.}
        inc(families.lastID)
        {.pop.}

      families.inputMap[inputs[i]] = family

  try:
    for input in inputs:
      families.families[family.id].incl(input)
  except KeyError:
    panic("Trying to add an input to its new family yet said new family doesn't exist.")

#The following are unsafe for two reasons:
#1) Use of temporal IDs
#2) Default to panic as families are solely internal and blockchain based
proc getFamilyIDUnsafe*(
  families: FamilyManager,
  input: Input
): uint64 {.inline, forceCheck: [].} =
  try:
    result = families.inputMap[input].resolve().id
  except KeyError:
    panic("Tried to get the family ID of an input not registered to a family: " & $input.hash)

proc getAndPruneFamilyUnsafe*(
  families: FamilyManager,
  id: uint64
): HashSet[Input] {.forceCheck: [].} =
  try:
    result = families.families[id]
  except KeyError:
    panic("Trying to get a family which doesn't exist")

  families.families.del(id)
  for input in result:
    families.inputMap.del(input)

when defined(merosTests):
  proc `==`*(
    f1: FamilyManager,
    f2: FamilyManager
  ): bool =
    if
      (f1.inputMap.keys().toSeq().toHashSet() != f2.inputMap.keys().toSeq().toHashSet() or
      (f1.families.len != f2.families.len)
    ):
      return

    var
      f1Keys: seq[uint64] = f1.families.keys()
      f2Keys: seq[uint64] = f2.families.keys()

    #[
      One of these will be flattened and one of these will be 'natural'.
      The actual family IDs are meaningless. We just need to make sure the values are the same.
      Reduceable to O(2n) by creating a unique ID for every possible value and checking the HashSet equality of both.
      Currently O(n^2).
    ]#
    while f1Keys.len != 0:
      var found: bool = true
      for k in f2Keys:
        if f1.families[f1Keys[0]] == f2.families[k]:
          f1Keys.del(0)
          found = true
          break
        if not found:
          return
    result = true
