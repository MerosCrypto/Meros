import sequtils
import deques
import hashes, sets, tables

import ../../../lib/[Errors, Hash]
import ../../Transactions/objects/TransactionObj
import ../../../objects/GlobalFunctionBoxObj

type
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

  Epochs* = ref object
    when not defined(merosTests):
      genesis: Hash.Hash[256]
      functions: GlobalFunctionBox
      height: uint
      lastID: uint
      inputMap: Table[Input, FamilyID]
      families: Table[uint, Family]
      epochs: Deque[HashSet[uint]]
    else:
      genesis*: Hash.Hash[256]
      functions*: GlobalFunctionBox
      height*: uint
      lastID*: uint
      inputMap*: Table[Input, FamilyID]
      families*: Table[uint, Family]
      epochs*: Deque[HashSet[uint]]

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

func newEpochs*(
  genesis: Hash.Hash[256],
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
func merge(
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
      queue &= epochs.families[target.id].dependants.toSeq()
    except KeyError as e:
      panic("Couldn't get a dependant family despite resolution: " & e.msg)

#Requires registration in order.
#Adding a transaction whose parent never went through Epochs will produce UB.
proc register*(
  epochs: Epochs,
  inputs: seq[Input],
  height: uint
) {.forceCheck: [].} =
  if epochs.height < height:
    inc(epochs.height)
    epochs.epochs.addLast(initHashSet[uint]())

  #Don't track families for magic inputs as used in Datas.
  #Could be inside the loop, yet such TXs only have one input.
  #Could have a check this is the only input, yet that's the only reason these hashes would be valid.
  #Not initialized due to a bug in Nim; for loop added to ensure its lack of value.
  var zeroHash: Hash.Hash[256]
  for b in 0 ..< 32:
    zeroHash.data[b] = 0
  if (inputs[0].hash == zeroHash) or (inputs[0].hash == epochs.genesis):
    return

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
    #Shouldn't be needed as uints shouldn't have overflow checks.
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
    family = epochs.families[familyID.resolve().id]
  except KeyError as e:
    panic("Couldn't get a family we just created: " & e.msg)
  for input in inputs:
    family.inputs.incl(input)
    epochs.inputMap[input] = familyID

    #Check if we're a dependent.
    #We do this by checking if we have any inputs whose inputs are in Epochs.
    try:
      for parentInput in epochs.functions.transactions.getTransaction(input.hash).inputs:
        #Doesn't need a check for being a magic input due to those never entering Epochs in the first place.
        var parent: uint
        try:
          parent = epochs.inputMap[parentInput].resolve().id
        except KeyError:
          continue

        try:
          epochs.families[parent].dependants.incl(familyID)
        except KeyError as e:
          panic("Couldn't get the family of a parent in Epochs: " & e.msg)
    except IndexError as e:
      panic("Couldn't get a Transaction despite it being in Epochs: " & e.msg)

#Pops off the newly finalized inputs.
func pop*(
  epochs: Epochs
): HashSet[Input] {.forceCheck: [].} =
  #Handle not having any Transactions included in the Block.
  if epochs.epochs.len == 5:
    inc(epochs.height)
    epochs.epochs.addLast(initHashSet[uint]())

  var families: HashSet[uint]
  try:
    families = epochs.epochs.popFirst()
  except IndexError as e:
    panic("Couldn't pop from the Epochs: " & e.msg)

  result = initHashSet[Input]()
  for family in families:
    try:
      for input in epochs.families[family].inputs:
        result.incl(input)
        epochs.inputMap.del(input)
      epochs.families.del(family)
    except KeyError as e:
      panic("Trying to pop a family which doesn't exist: " & e.msg)

when defined(merosTests):
  proc `==`*(
    e1: Epochs,
    e2: Epochs
  ): bool =
    if toSeq(e1.inputMap.keys()).toHashSet() != toSeq(e2.inputMap.keys()).toHashSet():
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
          if e1.families[f1].inputs == e2.families[f2].inputs:
            found = true
            break
        if not found:
          return false

    result = true
