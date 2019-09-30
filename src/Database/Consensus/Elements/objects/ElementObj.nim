#Finals lib.
import finals

#Element object.
finalsd:
    type
        Element* = ref object of RootObj
            #Owner's nickname.
            holder* {.final.}: uint32
