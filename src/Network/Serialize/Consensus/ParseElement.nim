#Errors lib.
import ../../../lib/Errors

#Serialization constants.
import ../SerializeCommon

#Get the length of the upcoming Element and check the data has the bytes in it.
proc getLength*(
    data: string,
    possibilities: set[int8],
    i: int,
    holder: string = ""
): int {.forceCheck: [
    ValueError
].} =
    if not (int8(data[i]) in possibilities):
        raise newException(ValueError, "Parsing an Element that isn't a valid Element for this data.")

    case int(data[i]):
        of VERIFICATION_PREFIX:
            result = NICKNAME_LEN + HASH_LEN
            if holder != "":
                result -= NICKNAME_LEN

            if data.len < result + i - 1:
                raise newException(ValueError, "parseElement not handed enough data to get a Verification.")
            inc(result)

        of VERIFICATION_PACKET_PREFIX:
            result = BYTE_LEN
            if data.len < result + i:
                raise newException(ValueError, "parseElement not handed enough data to get a Verification Packet's verifiers length.")

            var verifiers: int = data[i + 1 ..< i + 1 + result].fromBinary()
            result += (BLS_PUBLIC_KEY_LEN * verifiers) + HASH_LEN
            if data.len < result + i:
                raise newException(ValueError, "parseElement not handed enough data to get a Verification Packet's verifiers/hash.")

            inc(result)

        of MERIT_REMOVAL_PREFIX:
            result = NICKNAME_LEN + BYTE_LEN + BYTE_LEN
            if data.len < result + i:
                raise newException(ValueError, "parseElement not handed enough data to get the type of the first Element in the MeritRemoval.")

            for e in 0 ..< 2:
                try:
                    result += data.getLength(
                        {
                            int8(VERIFICATION_PREFIX),
                            int8(VERIFICATION_PACKET_PREFIX),
                            int8(SEND_DIFFICULTY_PREFIX),
                            int8(DATA_DIFFICULTY_PREFIX),
                            int8(GAS_PRICE_PREFIX)
                        },
                        i + result,
                        data[i + 1 ..< i + 1 + NICKNAME_LEN]
                    )
                except ValueError as e:
                    fcRaise e

                if (e == 0) and (data.len < result + i):
                    raise newException(ValueError, "parseElement not handed enough data to get the type of the second Element in the MeritRemoval.")

        else:
            raise newException(ValueError, "ParseElement's getLength tried to size an invalid/unsupported Element type.")
