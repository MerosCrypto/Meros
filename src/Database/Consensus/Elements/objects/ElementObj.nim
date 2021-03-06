type
  #Element object.
  #- Verification
  #- VerificationPacket
  #- SendDifficulty
  #- DataDifficulty
  #These are all descendants of Element as Merit Removals can have any of these as a cause.
  Element* = ref object of RootObj

  #Block Element object.
  #These are Elements which included in Blocks.
  #- SendDifficulty
  #- DataDifficulty
  #The holder field is defined here, not in Element, as VerificationPackets have multiple holders.
  #Verifications provide their own holder field.
  BlockElement* = ref object of Element
    #Creator's nickname.
    holder*: uint16

  #MeritRemoval is no longer an Element, and that inheritance should not be re-introduced.
  #That said, it's polymorphism was used for the MaliciousMeritHolder Exception.
  #This re-establishes it without bridging it to something it isn't.
  MeritRemovalParent* = ref object of RootObj
