#Entry object and descendants.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/MintObj
import ../../../Database/Lattice/objects/ClaimObj
import ../../../Database/Lattice/objects/SendObj
import ../../../Database/Lattice/objects/ReceiveObj
import ../../../Database/Lattice/objects/DataObj

#Serialize libs.
import SerializeMint
import SerializeClaim
import SerializeSend
import SerializeReceive
import SerializeData

#Serialize an Entry.
proc serialize*(entry: Entry): string =
    case entry.descendant:
        of EntryType.Mint:
            #We do not Serialize Mints for Network transmission.
            #This is used for saving a Mint to the DB.
            result = cast[Mint](entry).serialize()
        of EntryType.Claim:
            result = cast[Claim](entry).serialize()
        of EntryType.Send:
            result = cast[Send](entry).serialize()
        of EntryType.Receive:
            result = cast[Receive](entry).serialize()
        of EntryType.Data:
            result = cast[Data](entry).serialize()
