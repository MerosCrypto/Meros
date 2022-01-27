import json

import objects/ErrorObjs
export ErrorObjs

import Log
export Log

import Hash/objects/HashObj

import ../Database/Consensus/Elements/objects/MeritRemovalObj

proc newMaliciousMeritHolder*(
  msg: string,
  elem: Element or SignedMeritRemoval
): ref MaliciousMeritHolder {.forceCheck: [].} =
  result = newLoggedException(MaliciousMeritHolder, msg)
  when elem is SignedMeritRemoval:
    result.removalRef = elem
  else:
    result.element = elem

proc newSpam*(
  msg: string,
  hash: Hash[256],
  difficulty: uint32
): ref Spam {.forceCheck: [].} =
  result = newLoggedException(Spam, msg)
  result.hash = hash
  result.difficulty = difficulty

proc newJSONRPCError*[T: Exception or int](
  error: typedesc[T] or T,
  msg: string,
  data: JSONNode = nil
): ref JSONRPCError =
  result = newLoggedException(JSONRPCError, msg)
  when error is int:
    result.code = error
  elif error is Spam:
    result.code = 2
  elif error is NotEnoughMeros:
    result.code = 1
  elif error is DataMissing:
    result.code = -1
  elif error is IndexError:
    result.code = -2
  elif error is ValueError:
    result.code = -3
  else:
    {.error: "Unknown Exception type passed to newJSONRPCError".}
  result.data = data

#Getter for the MaliciousMeritHolder's removal as a MeritRemoval.
proc removal*(
  mmh: ref MaliciousMeritHolder
): SignedMeritRemoval {.inline, forceCheck: [].} =
  cast[SignedMeritRemoval](mmh.removalRef)
