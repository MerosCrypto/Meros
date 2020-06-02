#Errors lib.
import ../../lib/Errors

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Verificstion and Verification Packet lib.
import Elements/Verification
import Elements/VerificationPacket

#Transaction Status object.
import objects/TransactionStatusObj
export TransactionStatusObj

#Sets standard lib.
import sets

#Tables standard lib.
import tables

#Add a Verification.
proc add*(
  status: TransactionStatus,
  verif: SignedVerification
) {.forceCheck: [
  DataExists
].} =
  #Don't change the status of finalized Transactions.
  if status.merit != -1:
    return

  #Raise DataExists if this verifier was already added.
  if status.holders.contains(verif.holder):
    raise newLoggedException(DataExists, "Verification was already added.")

  #Add the holder to holders.
  status.holders.incl(verif.holder)
  status.pending.incl(verif.holder)

  #Add the Verification to the pending packet.
  status.packet.add(verif)
  #Cache the signature.
  status.signatures[verif.holder] = verif.signature

#Add a VerificationPacket.
#This is used to add a VerificationPacket from a Block.
proc add*(
  status: TransactionStatus,
  archived: VerificationPacket
) {.forceCheck: [].} =
  #Mark the holders in the sets.
  for holder in archived.holders:
    status.holders.incl(holder)
    status.pending.excl(holder)
    status.signatures.del(holder)

  var
    #Grab the existing pending packet.
    packet: SignedVerificationPacket = status.packet
    #List of signatures to aggregate for the new pending.
    signatures: seq[BLSSignature] = @[]

  #Regenerate the pending packet.
  status.packet = newSignedVerificationPacketObj(packet.hash)
  #Find holders the new packet is missing.
  for holder in packet.holders:
    #Add the holder, if they weren't archived.
    if status.pending.contains(holder):
      status.packet.holders.add(holder)
      try:
        signatures.add(status.signatures[holder])
      except KeyError as e:
        panic("Couldn't create a new pending VerificaionPacket due to missing signatures: " & e.msg)

  #Aggregate and set the signature.
  status.packet.signature = signatures.aggregate()
