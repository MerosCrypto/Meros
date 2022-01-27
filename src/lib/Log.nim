when not defined(merosTests):
  import chronicles
  export chronicles

#Wrappers around Chronicles.
#Mirrored in HashCommon.
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
