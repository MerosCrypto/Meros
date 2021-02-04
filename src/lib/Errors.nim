import json

when not defined(merosTests):
  import chronicles
  export chronicles

import objects/ErrorObjs
export ErrorObjs

import Hash/objects/HashObj

import ../Database/Consensus/Elements/objects/MeritRemovalObj

#Wrappers around Chronicles.
template panic*(
  msg: string
) =
  when not defined(merosTests):
    try:
      fatal "Panic", reason = msg
    except Exception:
      doAssert(false, "Couldn't log to the log file from panic.")

  doAssert(false, msg)

template logTrace*(
  eventName: static[string],
  props: varargs[untyped]
) =
  when not defined(merosTests):
    try:
      trace eventName, props
    except Exception:
      panic("Couldn't log to the log file from trace.")
  else:
    discard

template logDebug*(
  eventName: static[string],
  props: varargs[untyped]
) =
  when not defined(merosTests):
    try:
      debug eventName, props
    except Exception:
      panic("Couldn't log to the log file from debug.")
  else:
    discard

template logInfo*(
  eventName: static[string],
  props: varargs[untyped]
) =
  when not defined(merosTests):
    try:
      info eventName, props
    except Exception:
      panic("Couldn't log to the log file from info.")
  else:
    discard

template logNotice*(
  eventName: static[string],
  props: varargs[untyped]
) =
  when not defined(merosTests):
    try:
      notice eventName, props
    except Exception:
      panic("Couldn't log to the log file from notice.")
  else:
    discard

template logWarn*(
  eventName: static[string],
  props: varargs[untyped]
) =
  when not defined(merosTests):
    try:
      warn eventName, props
    except Exception:
      panic("Couldn't log to the log file from warn.")
  else:
    discard

template newLoggedException*(
  ExceptionType: typedesc,
  error: string
): untyped =
  logTrace "New Exception", msg = error
  newException(ExceptionType, error)

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
  argon: Hash[256],
  difficulty: uint32
): ref Spam {.forceCheck: [].} =
  result = newLoggedException(Spam, msg)
  result.hash = hash
  result.argon = argon
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
  elif error is DataExists:
    result.code = 0
  elif error is IndexError:
    result.code = -1
  elif error is ValueError:
    result.code = -2
  else:
    {.error: "Unknown Exception type passed to newJSONRPCError".}
  result.data = data

#Getter for the MaliciousMeritHolder's removal as a MeritRemoval.
proc removal*(
  mmh: ref MaliciousMeritHolder
): SignedMeritRemoval {.inline, forceCheck: [].} =
  cast[SignedMeritRemoval](mmh.removalRef)
