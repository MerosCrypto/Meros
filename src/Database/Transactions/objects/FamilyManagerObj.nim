import sets, tables

import ../../../lib/[Errors, Hash]
import ./TransactionObj

type
  FamilyID = ref object
    #Not a case statement as we need to be able to update this in realtime without re-instantiation
    active: bool
    id: uint64
    merged: FamilyID

  FamilyManager* = ref object
    genesis: Hash[256]
    lastID: uint64
    inputMap: Table[Input, FamilyID]
    families: Table[uint64, HashSet[Input]]

func newFamilyManager*(
  genesis: Hash[256]
): FamilyManager {.inline, forceCheck: [].} =
  FamilyManager(
    genesis: genesis,
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
    panic("Merging families when one doesn't exist.")
  families.families.del(source.id)

proc register*(
  families: FamilyManager,
  inputs: seq[Input]
) {.forceCheck: [].} =
  #Don't track families for magic inputs as used in Datas.
  if (inputs[0].hash == Hash[256]()) or (inputs[0].hash == families.genesis):
    return

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

        families.families[family.id] = initHashSet[Input]()

      families.inputMap[inputs[i]] = family
      try:
        families.families[family.id].incl(inputs[i])
      except KeyError:
        panic("Trying to include an input without a family into one which doesn't exist.")

  try:
    for input in inputs:
      families.families[family.id].incl(input)
  except KeyError:
    panic("Trying to add an input to its new family yet said new family doesn't exist.")

#The following is unsafe as it returns nothing when the family no longer exists.
proc getAndPruneFamilyUnsafe*(
  families: FamilyManager,
  inputArg: Input
): HashSet[Input] {.forceCheck: [].} =
  try:
    var id: uint64 = families.inputMap[inputArg].resolve().id
    result = families.families[id]
    families.families.del(id)
  #When multiple transactions share an input, or for magic inputs (Datas), this edge case is triggered.
  except KeyError:
    return

  for input in result:
    families.inputMap.del(input)

when defined(merosTests):
  proc `==`*(
    f1: FamilyManager,
    f2: FamilyManager
  ): bool =
    #For some reason, toSeq(keys).toHashSet() == doesn't work. This long form does.
    if f1.inputMap.len != f2.inputMap.len:
      return false
    for input in f1.inputMap.keys():
      if not f2.inputMap.hasKey(input):
        return false

    for input in f1.inputMap.keys():
      if f1.families[f1.inputMap[input].resolve().id].len != f2.families[f2.inputMap[input].resolve().id].len:
        return false
      for input in f1.families[f1.inputMap[input].resolve().id]:
        if not f2.families[f2.inputMap[input].resolve().id].contains(input):
          return false
    result = true
