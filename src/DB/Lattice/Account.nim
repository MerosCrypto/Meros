#Account object.
import objects/AccountObj
export AccountObj

#Create a new Account.
proc newAccount*(address: string): Account {.raises: [].} =
    newAccountObj(address)
