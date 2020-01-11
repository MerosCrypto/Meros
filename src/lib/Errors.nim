#Hash object.
import Hash/objects/HashObj

#Errors objects.
import objects/ErrorsObjs
export ErrorsObjs

#MeritRemoval object.
import ../Database/Consensus/Elements/objects/MeritRemovalObj

#JSON standard lib.
import json

#Constructors.
proc newMaliciousMeritHolder*(
    msg: string,
    elem: Element
): ref MaliciousMeritHolder {.forceCheck: [].} =
    result = newException(MaliciousMeritHolder, msg)
    result.element = elem

proc newSpam*(
    msg: string,
    hash: Hash[256],
    argon: Hash[256]
): ref Spam {.forceCheck: [].} =
    result = newException(Spam, msg)
    result.hash = hash
    result.argon = argon

proc newJSONRPCError*(
    code: int,
    msg: string,
    data: JSONNode = nil
): ref JSONRPCError =
    result = newException(JSONRPCError, msg)
    result.code = code
    result.data = data

#Getter for the MaliciousMeritHolder's removal as a MeritRemoval.
proc removal*(
    mmh: ref MaliciousMeritHolder
): MeritRemoval {.inline, forceCheck: [].} =
    cast[MeritRemoval](mmh.element)
