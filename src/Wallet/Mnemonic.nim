#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Hash lib.
import ../lib/Hash

#Math standard lib.
import math

#String utils standard lib.
import strutils

#Seq utils standard lib.
import sequtils

#Unicode Normalize lib.
import normalize

#Finals lib.
import finals

#Word List.
const
    LISTFILE: string = staticRead("WordLists/English.txt")
    LIST: seq[string] = LISTFILE.splitLines()

finalsd:
    type Mnemonic* = object
         entropy* {.final.}: string
         checksum* {.final.}: string
         sentence* {.final.}: string

#Create a Mnemonic from RNG.
proc newMnemonic*(): Mnemonic {.forceCheck: [].} =
    #Create the entropy.
    result.entropy = newString(32)
    try:
        randomFill(result.entropy)
    except RandomError as e:
        doAssert(false, "Couldn't generate entropy for a mnemonic: " & e.msg)

    #Calculate the checksum.
    result.checksum = $char(SHA2_256(result.entropy).data[0])

    var
        #Full string to encode.
        toEncode: string = result.entropy & result.checksum
        #Bit we're on.
        bit: int = 0
        #Byte byte we're on.
        i: int
        #Temporary variable for the data.
        temp: uint32

    #For every 11 bits...
    for _ in 0 ..< 24:
        #Set the byte.
        i = bit div 8

        #Set temp.
        temp = uint32(toEncode[i]) shl 16
        if i + 1 < toEncode.len:
            temp += uint32(toEncode[i + 1]) shl 8
        if i + 2 < toEncode.len:
            temp += uint32(toEncode[i + 2])

        #Add the matching word.
        result.sentence &= LIST[int(temp.extractBits((bit mod 8) + 8, 11))] & " "

        #Increase the bit by 11.
        bit += 11
    result.sentence = result.sentence[ 0 ..< result.sentence.len - 1]

    result.ffinalizeEntropy()
    result.ffinalizeChecksum()
    result.ffinalizeSentence()

#Create a Mnemonic from a sentence.
proc newMnemonic*(
    sentence: string
): Mnemonic  {.forceCheck: [
    ValueError
].} =
    #Split the sentence.
    var words: seq[string] = sentence.split(" ").filter(
        proc (
            word: string
        ): bool {.forceCheck: [].} =
            word != ""
    )

    #Set the sentence in the mnemonic.
    result.sentence = words.join(" ")

    #Decode the sentence.
    var
        #Bits in the sentence.
        bits: int = words.len * 11
        #Bytes needed to decode the sentence.
        bytes: int = int(ceil(bits / 8))
        #Decoded sentence.
        decoded: string = newString(bytes)

        #Word we're on.
        word: uint16
        #Bit we're on.
        bit: int = 0
        #Byte we're on.
        currentByte: int
        #Bits left in said byte.
        bitsLeft: int

    #Iterate over every word.
    for w in 0 ..< words.len:
        #Get the word's index.
        word = uint16(LIST.find(words[w]))

        #Update the current byte.
        currentByte = bit div 8
        bitsLeft = 8 - (bit mod 8)

        #Add the bits we can fit into the existing byte.
        decoded[currentByte] = char(
            uint8(decoded[currentByte]) + uint8(word shr (11 - bitsLeft))
        )

        #Set bitsLeft to the bits left in the word.
        bitsLeft = 11 - bitsLeft
        #Add the remaining bits to the next byte.
        decoded[currentByte + 1] = char(
            word shl (16 - bitsLeft) shr 8
        )
        #Update bits left.
        bitsLeft -= 8

        #If there are still bits left...
        if bitsLeft > 0:
            decoded[currentByte + 2] = char(
                word shl (16 - bitsLeft) shr 8
            )

        #Advance the bit we're on.
        bit += 11

    #Split the decoded data into the entropy and checksum.
    var
        #Checksum length entropy length div 32.
        #This means the checksum length is bits mod 32 EXCEPT when the bits is over 32 * 32.
        checksumLen: int = (bits mod 32) + ((bits div (32 * 32)) * 32)
        #Entropy length is bits - checksum length/
        entropyLen: int = bits - checksumLen

    #Verify the entropy length.
    if entropyLen mod 32 != 0:
        raise newException(ValueError, "Invalid length entropy.")

    #Extract the entropy from decoded.
    result.entropy = newString(entropyLen div 8)
    for e in 0 ..< result.entropy.len:
        result.entropy[e] = decoded[e]
    #Remove the entropy from decoded.
    decoded = decoded.substr(result.entropy.len)

    #Extract the checksum.
    result.checksum = newString(int(ceil(checksumLen / 8)))
    var checksumHash: SHA2_256Hash = SHA2_256(result.entropy)
    for c in 0 ..< result.checksum.len:
        #If the checksum isn't a clean byte...
        if checksumLen < 8:
            #Only extract the needed bits.
            result.checksum[c] = char(checksumHash.data[c] shr (8 - checksumLen) shl (8 - checksumLen))
            break

        #Extract the byte.
        result.checksum[c] = char(checksumHash.data[c])

        #Lower the checksum length.
        checksumLen -= 8

    #Verify the checksum.
    if result.checksum != decoded:
        raise newException(ValueError, "Invalid checksum.")

#Generate a secret using the Mnemonic and the password.
proc unlock*(
    mnemonic: Mnemonic,
    password: string = ""
): string {.forceCheck: [].} =
    PDKDF2_HMAC_SHA2_512(mnemonic.sentence.toNFKD(), ("mnemonic" & password.toNFKD())).toString()
