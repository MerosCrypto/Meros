#Tests proper handling of Verifications with unsynced Transactions which are beaten by other Transactions.

#Types.
from typing import Dict, IO, Any

#Transactions class.
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from python_tests.Classes.Consensus.Verification import Verification
from python_tests.Classes.Consensus.Consensus import Consensus

#TestError Exception.
from python_tests.Tests.TestError import TestError

#Merit classes.
from python_tests.Classes.Merit.Merit import Merit

#Meros classes.
from python_tests.Meros.Meros import MessageType
from python_tests.Meros.RPC import RPC

#Merit, Consensus, and Transactions verifiers.
from python_tests.Tests.Merit.Verify import verifyBlockchain
from python_tests.Tests.Consensus.Verify import verifyConsensus
from python_tests.Tests.Transactions.Verify import verifyTransactions

#BLS lib.
import blspy

#JSON standard lib.
import json

def VCompeting(
    rpc: RPC
) -> None:
    cFile: IO[Any] = open("python_tests/Vectors/Consensus/Verification/Competing.json", "r")
    cVectors: Dict[str, Any] = json.loads(cFile.read())
    #Transactions.
    transactions: Transactions = Transactions.fromJSON(
        cVectors["transactions"]
    )
    #Consensus.
    consensus: Consensus = Consensus.fromJSON(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"),
        cVectors["consensus"]
    )
    #Merit.
    merit: Merit = Merit.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        100,
        transactions,
        consensus,
        cVectors["blockchain"]
    )
    cFile.close()

    #Key which signed the failed Transaction.
    blsPubKey: blspy.PublicKey = blspy.PrivateKey.from_seed(b'\1').get_public_key()
    #Failed Transaction.
    failedTX: bytes = Verification.fromElement(consensus.holders[blsPubKey.serialize()][0]).hash

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        len(merit.blockchain.blocks)
    )

    sentLast: int = 4
    hash: bytes = bytes()
    while True:
        msg: bytes = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height: int = int.from_bytes(msg[1 : 5], byteorder = "big")
            if height == 0:
                rpc.meros.blockHash(merit.blockchain.last())
            else:
                if height >= len(merit.blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(merit.blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            hash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == merit.blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            hash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockBody(block.body)
                    break

                if block.header.hash == merit.blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.ElementRequest:
            rpc.meros.element(
                consensus.holders[
                    msg[1 : 49]
                ][
                    int.from_bytes(msg[49 : 53], byteorder = "big")
                ]
            )

        elif MessageType(msg[0]) == MessageType.TransactionRequest:
            sentLast -= 1
            rpc.meros.transaction(transactions.txs[
                msg[1 : 49]
            ])


        elif MessageType(msg[0]) == MessageType.SyncingOver:
            if sentLast == 0:
                break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Verify the beat Transaction was saved over the RPC.
    if rpc.call("transactions", "getTransaction", [failedTX.hex()]) != transactions.txs[failedTX].toJSON():
        raise TestError("Meros didn't save the failed competing Transaction.")

    #Verify the Blockchain.
    verifyBlockchain(rpc, merit.blockchain)

    #Verify the Transactions.
    verifyTransactions(rpc, transactions)

    #Verify the Consensus.
    verifyConsensus(rpc, consensus)

    #Playback their messages.
    rpc.meros.playback()
