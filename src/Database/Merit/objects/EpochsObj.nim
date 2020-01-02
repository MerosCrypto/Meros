#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Merit DB lib.
import ../../Filesystem/DB/MeritDB

#VerificationPacket object.
import ../../Consensus/Elements/objects/VerificationPacketObj

#Seq utils standard lib.
import sequtils

#Tables standard lib.
import tables

type
    #Reward object.
    Reward* = object
        nick*: uint16
        score*: uint64

    #Epoch object. Transaction Hash -> Nicks of verifiers.
    Epoch* = Table[Hash[384], seq[uint16]]

    #Epochs object. Seq of the current 5 Epochs.
    Epochs* = seq[Epoch]

#Constructors.
func newReward*(
    nick: uint16,
    score: uint64
): Reward {.inline, forceCheck: [].} =
    Reward(
        nick: nick,
        score: score
    )

func newEpoch*(): Epoch {.inline, forceCheck: [].} =
    initTable[Hash[384], seq[uint16]]()

func newEpochsObj*(): Epochs {.forceCheck: [].} =
    #Create the seq.
    result = newSeq[Epoch](5)

    #Place blank epochs in.
    for i in 0 ..< 5:
        result[i] = newEpoch()

#Register a hash within an Epoch.
func register*(
    epoch: var Epoch,
    hash: Hash[384]
) {.inline, forceCheck: [].} =
    epoch[hash] = @[]

#Add a VerificationPacket to an Epoch.
func add*(
    epoch: var Epoch,
    packet: VerificationPacket
) {.forceCheck: [].} =
    try:
        epoch[packet.hash] = epoch[packet.hash].concat(packet.holders)
    except KeyError as e:
        doAssert(false, "Adding a packet to an Epoch which doesn't have that hash registered: " & e.msg)

#Shift an Epoch.
proc shift*(
    epochs: var Epochs,
    epoch: Epoch
): Epoch {.forceCheck: [].} =
    #Add the newest Epoch.
    epochs.add(epoch)
    #Set the result to the oldest.
    result = epochs[0]
    #Remove the oldest.
    epochs.delete(0)

#Get the latest Epoch.
func latest*(
    epochs: Epochs
): Epoch {.inline, forceCheck: [].} =
    epochs[4]
