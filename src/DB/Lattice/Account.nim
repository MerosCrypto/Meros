#Number libs.
import ../../lib/BN
import ../../lib/Base

#Time lib.
import ../../lib/Time

#Transaction and Difficulty libs.
import Transaction as TransactionFile

#Lists standard lib.
import lists

#Account object.
type Account* = ref object of RootObj
    #Chain owner.
    address: string
    #Account height. BN for compatibility.
    height: BN
    #Doubly Linked List of all the Transactions.
    transactions: DoublyLinkedList[Transaction]
    #Balance of the addres.
    balance: BN

#Create a new Account.
proc newAccount*(address: string): Account {.raises: [].} =
    #Init the object.
    result = Account(
        address: address,
        height: newBN(),
        transactions: initDoublyLinkedList[Transaction](),
        balance: newBN()
    )

proc getTransactions*(account: Account): DoublyLinkedList[Transaction] {.raises: [].} =
    result = account.transactions

iterator getTransactions*(account: Account): Transaction {.raises: [].} =
    for i in account.transactions.items():
        yield i
