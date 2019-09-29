#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Verification Packet object.
import VerificationPacketObj

#Finals lib.
import finals

import objects/TransactionStatus
import VerificationPacket

#Add a Verification.
proc add*(
    status: TransactionStatus,
    verif: Verification
) {.forceCheck: [].} =
    status.pending.add(verif)

#Add a VerificationPacket.
#This is used to add a VerificationPacket from a Block.
proc add*(
    status: TransactionStatus,
    packet: VerificationPacket
) {.forceCheck: [].} =
    #Add the new packet to the list of packets.
    status,packets.add(packet)

    var
        #Grab the pending packet.
        pending: SignedVerificationPacket = status.pending
        #List of signatures to aggregate for the new pending.
        signatures: seq[BLSSignature] = @[]
        #Holder we're currently working with.
        holder: int

    #Clear pending.
    status.pending = newSignedVerificationPacket()
    #Find holders the new packet is missing.
    for h in 0 ..< pending.holders.len:
        holder = pending.holders[h]
        if not packet.holders.contains(holder):
            #If the new packet is missing holders, add the holder to the recreated pending.
            status.pending.holders.add(holder)
            #Add their signature to the signature seq.
            signatures.add(pending.signatures[h])

    #Aggregate and set the signature.
    try:
        status.pending.signature = signatures.aggregate()
    except BLSError as e:
        doAssert(false, "Failed to aggregate the signatures of holders not included in the archived packet: " & e.msg)
