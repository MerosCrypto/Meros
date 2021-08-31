import sequtils
import deques
import hashes, sets, tables

import ../../../lib/[Errors, Hash]
import ../../Transactions/objects/TransactionObj
import ../../../objects/GlobalFunctionBoxObj

type
  #Workaround for the conflicting hash definitions caused by hashes/Hash.
  MerosHash = Hash.Hash[256]

  FamilyID = ref object
    #Whether or not this family had been merged.
    #Not a case statement as we need to be able to update this in realtime without re-instantiation.
    active: bool
    #Numeric ID.
    id: uint
    #What it was merged into.
    merged: FamilyID

  Family = ref object
    #Inputs in this family.
    inputs: HashSet[Input]
    #Families that depend on this.
    dependants: HashSet[FamilyID]
    #Height created at.
    created: uint
    #Datas assigned to this family. Required due to their use of magic inputs.
    #Only one is ever assigned at a time. This could be transformed into an Option.
    datas*: seq[MerosHash]

  Epochs* = ref object
    genesis*: MerosHash
    functions*: GlobalFunctionBox
    height*: uint
    when not defined(merosTests):
      lastID: uint
      inputMap*: Table[Input, FamilyID]
      families*: Table[uint, Family]
      epochs: Deque[HashSet[uint]]
    else:
      lastID*: uint
      inputMap*: Table[Input, FamilyID]
      families*: Table[uint, Family]
      epochs*: Deque[HashSet[uint]]
    currentTXs*: HashSet[MerosHash]
    datas*: HashSet[MerosHash]

func resolve(
  id: FamilyID
): FamilyID {.inline, forceCheck: [].} =
  result = id
  while not result.active:
    result = result.merged

func hash(
  id: FamilyID
): hashes.Hash {.forceCheck: [].} =
  hash(id.resolve().id)

func newEpochsObj*(
  genesis: MerosHash,
  functions: GlobalFunctionBox,
  height: uint
): Epochs {.forceCheck: [].} =
  result = Epochs(
    genesis: genesis,
    functions: functions,
    height: height,
    lastID: 1,
    inputMap: initTable[Input, FamilyID](),
    families: initTable[uint, Family](),
    epochs: initDeque[HashSet[uint]]()
  )
  for _ in 0 ..< 5:
    result.epochs.addLast(initHashSet[uint]())

#Works for the case where a single family is passed.
#Also brings up merged families and dependents.
proc merge(
  epochs: Epochs,
  families: seq[FamilyID]
): FamilyID {.forceCheck: [].} =
  var target: FamilyID = families[0].resolve()

  for rawSource in families[1 ..< families.len]:
    #Resolve the source.
    var source: FamilyID = rawSource.resolve()

    #Forward the source ID to point to the target.
    source.active = false
    source.merged = target

    #Merge the families.
    try:
      var
        family: Family = epochs.families[target.id]
        other: Family = epochs.families[source.id]
      family.inputs = family.inputs + other.inputs
      family.dependants = family.dependants + other.dependants
      #Use the older creation time.
      family.created = min(family.created, other.created)
    except KeyError as e:
      panic("Merging families when one doesn't exist: " & e.msg)

    #Delete the source. Its ID is kept in the inputMap though.
    epochs.families.del(source.id)
    for e in 0 ..< epochs.epochs.len:
      try:
        epochs.epochs[e].excl(source.id)
      except IndexError as e:
        panic("IndexError despite iterating from 0 ..< len: " & e.msg)

  #We merge families when they have new competitors added.
  #Bring up all families and dependants on that premise.
  var queue: seq[FamilyID] = @[target]
  while queue.len != 0:
    #Bring up the current family.
    target = queue[^1].resolve()
    queue.del(queue.len - 1)
    for e in 0 ..< (epochs.epochs.len - 1):
      try:
        epochs.epochs[e].excl(target.id)
      except IndexError as e:
        panic("IndexError despite iterating from 0 ..< len - 1: " & e.msg)
    try:
      epochs.epochs[^1].incl(target.id)
    except IndexError as e:
      panic("IndexError despite using a BackwardsIndex: " & e.msg)

    #Queue its dependants.
    #These could have duplicates, yet Epochs being a HashSet nullifies these concerns.
    try:
      for dependant in epochs.families[target.id].dependants.toSeq():
        #Don't queue if it was already brought up.
        #Needed due to cyclical dependencies caused by impossible transactions.
        if epochs.epochs[^1].contains(dependant.resolve().id):
          continue
        queue.add(dependant)
    except IndexError as e:
      panic("IndexError despite using a BackwardsIndex: " & e.msg)
    except KeyError as e:
      panic("Couldn't get a dependant family despite resolution: " & e.msg)

  result = target

#Requires registration in order.
#Adding a transaction whose parent never went through Epochs will produce UB.
proc register*(
  epochs: Epochs,
  hash: MerosHash,
  inputs: seq[Input],
  height: uint
) {.forceCheck: [].} =
  #TODO: Check this runs on the very first Block added.
  if epochs.height < height:
    inc(epochs.height)
    epochs.epochs.addLast(initHashSet[uint]())

  #Don't track families for magic inputs as used in Datas.
  #Could be inside the loop, yet such TXs only have one input.
  #Could have a check this is the only input, yet that's the only reason these hashes would be valid.
  if (inputs[0].hash == MerosHash()) or (inputs[0].hash == epochs.genesis):
    #Do still create a family so it's marked in the finalization queue.
    #This won't be able to track descendants, yet these Transactions are never brought up, so this is a non-issue.
    epochs.families[epochs.lastID] = Family(
      created: height,
      datas: @[hash]
    )
    epochs.datas.incl(hash)

    try:
      epochs.epochs[^1].incl(epochs.lastID)
    except IndexError as e:
      panic("IndexError despite using a BackwardsIndex to add to the latest Epoch: " & e.msg)

    #Shouldn't be needed as uints shouldn't have overflow checks.
    {.push boundChecks: off.}
    inc(epochs.lastID)
    {.pop.}
    return

  epochs.currentTXs.incl(hash)

  #Gather existing families.
  var families: HashSet[FamilyID] = initHashSet[FamilyID]()
  for input in inputs:
    try:
      families.incl(epochs.inputMap[input].resolve())
    except KeyError:
      continue

  var familyID: FamilyID
  #New family. Most common case.
  if families.len == 0:
    familyID = FamilyID(
      active: true,
      id: epochs.lastID
    )
    {.push boundChecks: off.}
    inc(epochs.lastID)
    {.pop.}

    epochs.families[familyID.id] = Family(
      inputs: initHashSet[Input](),
      dependants: initHashSet[FamilyID](),
      created: height
    )

    try:
      epochs.epochs[^1].incl(familyID.id)
    except IndexError as e:
      panic("IndexError despite using a BackwardsIndex to add to the latest Epoch: " & e.msg)

  #Families exist, which now need to be merged.
  else:
    familyID = epochs.merge(families.toSeq())

  #Add ourselves to the family.
  var family: Family
  try:
    family = epochs.families[familyID.id]
  except KeyError as e:
    panic("Couldn't get a family we just created: " & e.msg)
  for input in inputs:
    family.inputs.incl(input)
    epochs.inputMap[input] = familyID

    #Check if we're a dependent.
    #We do this by checking if we have any inputs whose inputs are in Epochs.
    #This should be optimizable using currentTXs.
    try:
      for parentInput in epochs.functions.transactions.getTransaction(input.hash).inputs:
        #Doesn't need a check for being a magic input due to those never entering Epochs in the first place.
        var parent: FamilyID
        try:
          parent = epochs.inputMap[parentInput]
        except KeyError:
          continue

        try:
          epochs.families[parent.resolve().id].dependants.incl(familyID)
        except KeyError as e:
          panic("Couldn't get the family of a parent in Epochs: " & e.msg)
    except IndexError as e:
      panic("Couldn't get a Transaction despite it being in Epochs: " & e.msg)

#Pops off the newly finalized inputs.
proc pop*(
  epochs: Epochs
): HashSet[MerosHash] {.forceCheck: [].} =
  #Handle not having any Transactions included in the Block.
  if epochs.epochs.len == 5:
    inc(epochs.height)
    epochs.epochs.addLast(initHashSet[uint]())

  var families: HashSet[uint]
  try:
    families = epochs.epochs.popFirst()
  except IndexError as e:
    panic("Couldn't pop from the Epochs: " & e.msg)

  result = initHashSet[MerosHash]()
  for family in families:
    try:
      for input in epochs.families[family].inputs:
        result = result + epochs.functions.transactions.getSpenders(input).toHashSet()
        epochs.inputMap.del(input)

      if epochs.families[family].datas.len != 0:
        result.incl(epochs.families[family].datas[0])
        epochs.datas.excl(epochs.families[family].datas[0])
    except KeyError as e:
      panic("Trying to pop a family which doesn't exist: " & e.msg)
    epochs.families.del(family)

  epochs.currentTXs = epochs.currentTXs - result

when defined(merosTests):
  proc `==`*(
    e1: Epochs,
    e2: Epochs
  ): bool =
    if e1.height != e2.height:
      return false

    for input in toSeq(e1.inputMap.keys()).toHashSet():
      if not e2.inputMap.hasKey(input):
        return false

    for input in e1.inputMap.keys():
      var
        f1 = e1.families[e1.inputMap[input].resolve().id]
        f2 = e2.families[e2.inputMap[input].resolve().id]
      if f1.inputs != f2.inputs:
        return false
      if f1.created != f2.created:
        return false
      #Doesn't check dependants length as duplicates may exist.
      for dependant in f1.dependants:
        let dependants: HashSet[Input] = e1.families[dependant.resolve().id].inputs
        var found: bool = false
        for possibility in f2.dependants:
          if e2.families[possibility.resolve().id].inputs == dependants:
            found = true
            break
        if not found:
          return false

    if e1.epochs.len != e2.epochs.len:
      panic("Epochs length was different. Even in testing, this should never happen.")
    for e in 0 ..< e1.epochs.len:
      for f1 in e1.epochs[e]:
        #No risk of duplicates; just a lack of a canonical ordering.
        var found: bool = false
        for f2 in e2.epochs[e]:
          if (e1.families[f1].inputs == e2.families[f2].inputs) and (e1.families[f1].datas == e2.families[f2].datas):
            found = true
            break
        if not found:
          return false

    if (e1.currentTXs != e2.currentTXs) or (e1.datas != e2.datas):
      return false

    result = true
