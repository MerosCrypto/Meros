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

#BN lib.
import BN

#Add a Mint.
proc add*(
    account: Account,
    mint: Mint
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    AddressError,
    EdPublicKeyError
].} =
    try:
        account.add(cast[Entry](mint))
    except ValueError as e:
        raise e
    except IndexError as e:
        raise e
    except GapError as e:
        raise e
    except AddressError as e:
        raise e
    except EdPublicKeyError as e:
        raise e

#Add a Claim.
proc add*(
    account: Account,
    claim: Claim,
    mint: Mint
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    AddressError,
    EdPublicKeyError,
    BLSError
].} =
    #Verify the BLS signature is for this mint and this person.
    try:
        claim.bls.setAggregationInfo(
            newBLSAggregationInfo(
                newBLSPublicKey(mint.output),
                mint.nonce.toBinary() & Address.toPublicKey(account.address)
            )
        )
    except AddressError as e:
        raise e
    except BLSError as e:
        raise e
    if not claim.bls.verify():
        raise newException(ValueError, "Claim had invalid BLS signature.")

    #Verify it's unclaimed.

    #Add the Claim.
    try:
        account.add(cast[Entry](claim))
    except ValueError as e:
        raise e
    except IndexError as e:
        raise e
    except GapError as e:
        raise e
    except AddressError as e:
        raise e
    except EdPublicKeyError as e:
        raise e

#Add a Send.
proc add*(
    account: Account,
    send: Send,
    difficulty: BN
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    AddressError,
    EdPublicKeyError
].} =
    #Verify the work.
    if send.argon.toBN() < difficulty:
        raise newException(ValueError, "Failed to verify the Send's work.")

    #Verify the output is a valid address.
    if not Address.isValid(send.output):
        raise newException(ValueError, "Failed to verify the Send's output.")

    #Verify the account has enough money.
    if account.balance < send.amount:
        raise newException(ValueError, "Sender doesn't have enough monery for this Send.")

    #Add the Send.
    try:
        account.add(cast[Entry](send))
    except ValueError as e:
        raise e
    except IndexError as e:
        raise e
    except GapError as e:
        raise e
    except AddressError as e:
        raise e
    except EdPublicKeyError as e:
        raise e

#Add a Receive.
proc add*(
    account: Account,
    recv: Receive,
    sendArg: Entry
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    AddressError,
    EdPublicKeyError
].} =
    #Verify the entry is a Send.
    if sendArg.descendant != EntryType.Send:
        raise newException(ValueError, "Trying to Receive from an Entry that isn't a Send.")

    #Cast it to a Send.
    var send: Send = cast[Send](sendArg)

    #Verify the Send's output address.
    if account.address != send.output:
        raise newException(ValueError, "Receiver is trying to receive from a Send which isn't for them.")

    #Verify it's unclaimed.

    #Add the Receive.
    try:
        account.add(cast[Entry](recv))
    except ValueError as e:
        raise e
    except IndexError as e:
        raise e
    except GapError as e:
        raise e
    except AddressError as e:
        raise e
    except EdPublicKeyError as e:
        raise e

#Add Data.
proc add*(
    account: Account,
    data: Data,
    difficulty: BN
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    AddressError,
    EdPublicKeyError
].} =
    #Verify the work.
    if data.argon.toBN() < difficulty:
        raise newException(ValueError, "Failed to verify the Data's work.")

    #Add the Data.
    try:
        account.add(cast[Entry](data))
    except ValueError as e:
        raise e
    except IndexError as e:
        raise e
    except GapError as e:
        raise e
    except AddressError as e:
        raise e
    except EdPublicKeyError as e:
        raise e
