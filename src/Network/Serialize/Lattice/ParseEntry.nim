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

#Parses an entry prefixed by the type.
proc parseEntry*(
    entry: string
): Entry {.forceCheck: [
    ValueError,
    ArgonError,
    BLSError,
    EdPublicKeyError
].} =
    try:
        case EntryType(entry[0]):
            of EntryType.Mint:
                return entry.substr(1).parseMint()
            of EntryType.Claim:
                return entry.substr(1).parseClaim()
            of EntryType.Send:
                return entry.substr(1).parseSend()
            of EntryType.Receive:
                return entry.substr(1).parseReceive()
            of EntryType.Data:
                return entry.substr(1).parseData()
    except ValueError as e:
        raise e
    except ArgonError as e:
        raise e
    except BLSError as e:
        raise e
    except EdPublicKeyError as e:
        raise e
