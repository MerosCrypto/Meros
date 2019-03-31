#Errors lib.
import ../../../lib/Errors

#Entry object.
import ../../../Database/Lattice/objects/EntryObj

#Parse Entry libs.
import ParseMint
import ParseClaim
import ParseSend
import ParseReceive
import ParseData

#Finals lib.
import finals

#Parses an entry prefixed by the type.
proc parseEntry*(entry: string): Entry {.raises: [
    ValueError,
    ArgonError,
    BLSError,
    SodiumError,
    FinalAttributeError
].} =
    case EntryType(entry[0]):
        of EntryType.Mint:
            return entry[1 .. entry.len].parseMint()
        of EntryType.Claim:
            return entry[1 .. entry.len].parseClaim()
        of EntryType.Send:
            return entry[1 .. entry.len].parseSend()
        of EntryType.Receive:
            return entry[1 .. entry.len].parseReceive()
        of EntryType.Data:
            return entry[1 .. entry.len].parseData()
