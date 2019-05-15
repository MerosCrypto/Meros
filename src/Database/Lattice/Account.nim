#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Wallet libs.
import ../../Wallet/Address
import ../../Wallet/Wallet

#LatticeIndex object.
import ../common/objects/LatticeIndexObj

#Entry object and descendants.
import objects/EntryObj
import objects/MintObj
import objects/ClaimObj
import objects/SendObj
import objects/ReceiveObj
import objects/DataObj

#Account object.
import objects/AccountObj
export AccountObj

#Tables lib.
import tables

#Add a Mint.
proc add*(
    account: Account,
    mint: Mint
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    EdPublicKeyError,
    DataExists
].} =
    try:
        account.add(cast[Entry](mint))
    except ValueError as e:
        fcRaise e
    except IndexError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except EdPublicKeyError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e

#Add a Claim.
proc add*(
    account: Account,
    claim: Claim,
    minter: Account
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    EdPublicKeyError,
    BLSError,
    DataExists
].} =
    #Verify it's unclaimed.
    #This also confirms the Minter has an Entry at said nonce.
    try:
        discard minter.claimable[claim.mintNonce]
    #Not claimable.
    except KeyError:
        raise newException(ValueError, "Claim is for a claimed Mint.")

    #Verify the BLS signature is for this Mint and this person.
    var mint: Mint
    try:
        mint = cast[Mint](minter[claim.mintNonce])
    except ValueError as e:
        doAssert(false, "Couldn't grab a Mint despite it being claimable due to a ValueError: " & e.msg)
    except IndexError as e:
        doAssert(false, "Couldn't grab a Mint despite it being claimable due to an IndexError: " & e.msg)

    try:
        claim.bls.setAggregationInfo(
            newBLSAggregationInfo(
                mint.output,
                "claim" & mint.nonce.toBinary() & Address.toPublicKey(account.address)
            )
        )
        if not claim.bls.verify():
            raise newException(ValueError, "Claim had invalid BLS signature.")
    except AddressError:
        doAssert(false, "Created an account with an invalid address.")
    except BLSError as e:
        fcRaise e

    #Add the Claim.
    try:
        account.add(cast[Entry](claim))
    except ValueError as e:
        fcRaise e
    except IndexError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except EdPublicKeyError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e

#Add a Send.
proc add*(
    account: Account,
    send: Send,
    difficulty: Hash[384]
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    EdPublicKeyError,
    DataExists
].} =
    #Verify the work.
    if send.argon <= difficulty:
        raise newException(ValueError, "Failed to verify the Send's work.")

    #Verify the output is a valid address.
    if not Address.isValid(send.output):
        raise newException(ValueError, "Failed to verify the Send's output.")

    #Verify the account has enough money.
    if account.balance - account.potentialDebt < send.amount:
        raise newException(ValueError, "Sender doesn't have enough monery for this Send.")

    #Add the Send.
    try:
        account.add(cast[Entry](send))
    except ValueError as e:
        fcRaise e
    except IndexError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except EdPublicKeyError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e

#Add a Receive.
proc add*(
    account: Account,
    recv: Receive,
    sender: Account
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    EdPublicKeyError,
    DataExists
].} =
    #Verify it's unclaimed.
    try:
        discard sender.claimable[recv.input.nonce]
    #Not claimable.
    except KeyError:
        raise newException(ValueError, "Receive is for a claimed Entry.")

    #Verify it's a Send.
    if sender.address == "minter":
        raise newException(ValueError, "Receive is for a Mint. This should never happen.")

    #Verify the Send's output address.
    try:
        if recv.sender != cast[Send](sender[recv.input.nonce]).output:
            raise newException(GapError, "Receive is for a Send not to the Receive's sender.")
    #Use GapError as it's a custom error that's guaranteed to not be raised, when we do have to handle ValueError..
    except ValueError as e:
        doAssert(false, "Couldn't grab a Send despite it being claimable due to a ValueError: " & e.msg)
    except IndexError as e:
        doAssert(false, "Couldn't grab a Send despite it being claimable due to an IndexError: " & e.msg)
    except GapError as e:
        raise newException(ValueError, e.msg)

    #Add the Receive.
    try:
        account.add(cast[Entry](recv))
    except ValueError as e:
        fcRaise e
    except IndexError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except EdPublicKeyError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e

#Add Data.
proc add*(
    account: Account,
    data: Data,
    difficulty: Hash[384]
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    EdPublicKeyError,
    DataExists
].} =
    #Verify the work.
    if data.argon <= difficulty:
        raise newException(ValueError, "Failed to verify the Data's work.")

    #Add the Data.
    try:
        account.add(cast[Entry](data))
    except ValueError as e:
        fcRaise e
    except IndexError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except EdPublicKeyError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
