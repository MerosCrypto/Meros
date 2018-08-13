import ../src/Wallet/PublicKey
import ../src/Wallet/Address

type StringPair = ref object of RootObj
    key: string
    address: string
type KeyPair = ref object of RootObj
    key: PublicKey
    address: string

proc Pair(key: string, address: string): StringPair {.raises: [].} =
    result = StringPair(
        key: key,
        address: address
    )
proc Pair(key: PublicKey, address: string): KeyPair {.raises: [].} =
    result = KeyPair(
        key: key,
        address: address
    )

var address: string
proc test(pair: StringPair): string {.raises: [ValueError, Exception].} =
    result = ""

    try:
        address = newAddress(pair.key)
    except:
        result = "Generating the address from " & pair.key & " threw an error."
    if (address != pair.address) or (not Address.verify(address, pair.key)):
        result = "Address " & address & " either did not equal " & pair.address & " or was invalid."
        return
proc test(pair: KeyPair): string {.raises: [ValueError].} =
    result = ""

    try:
        address = newAddress(pair.key)
    except:
        result = "Generating the address from " & $pair.key & " threw an error."
    if (address != pair.address) or (not Address.verify(address)):
        result = "Address " & address & " either did not equal " & pair.address & " or was invalid."
        return

proc suite*(): string {.raises: [ValueError, Exception].} =
    result = ""

    var
        stringPairs: seq[StringPair] = @[]
        keyPairs: seq[KeyPair] = @[]
        addresses: seq[string] = @[
            "Emb123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxy", #60 length.
            "Emb123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz", #Every Base58 char.
            "Emb123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz123" #64 length.
        ]

    for pair in stringPairs:
        result = test(pair)
        if result != "":
            result =
                "Address Test with a key of: " & pair.key &
                " and address of: " & pair.address &
                " failed. Error: " & result
            return

    for pair in keyPairs:
        result = test(pair)
        if result != "":
            result =
                "Address Test with a key of: " & $pair.key &
                " and address of: " & pair.address &
                " failed. Error: " & result
            return

    for address in addresses:
        if not Address.verify(address):
            result =
                "Address Test with a address of: " & address &
                " failed. Error: " & result
            return

var res = suite()
if res == "":
    echo "Success."
else:
    echo res
