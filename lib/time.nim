import times

proc getTime*(): uint32 =
    result = (uint32) epochTime()
