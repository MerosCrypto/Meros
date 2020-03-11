type
    #Element object.
    #- Verification
    #- VerificationPacket
    #- SendDifficulty
    #- DataDifficulty
    #- GasDifficulty
    #- MeritRemoval
    #These are all descendants of Element as Merit Removals can have any of these as a cause.
    Element* = ref object of RootObj

    #Block Element object.
    #These are Elements which included in Blocks.
    #- SendDifficulty
    #- DataDifficulty
    #- GasDifficulty
    #- MeritRemoval
    #The holder field is defined here, not in Element, as VerificationPackets have multiple holders.
    BlockElement* = ref object of Element
        #Creator's nickname.
        holder*: uint16
