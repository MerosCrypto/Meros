#https://github.com/MerosCrypto/Meros/issues/50

#Types.
from typing import Dict, List, IO, Any

#Merit classes.
from python_tests.Classes.Merit.Merit import Merit

#Transactions class.
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from python_tests.Classes.Consensus.Verification import Verification
from python_tests.Classes.Consensus.Consensus import Consensus

#Meros classes.
from python_tests.Meros.Meros import MessageType
from python_tests.Meros.RPC import RPC

#JSON standard lib.
import json

def FiftyTest(
    rpc: RPC
) -> None:
    cmFile: IO[Any] = open("python_tests/Vectors/Transactions/Fifty.json", "r")
    cmVectors: Dict[str, Any] = json.loads(cmFile.read())
    #Transactions.
    transactions: Transactions = Transactions.fromJSON(
        cmVectors["transactions"]
    )
    #Consensus.
    consensus: Consensus = Consensus.fromJSON(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"),
        cmVectors["consensus"]
    )
    #Merit.
    merit: Merit = Merit.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        100,
        transactions,
        consensus,
        cmVectors["blockchain"]
    )
    cmFile.close()

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        len(merit.blockchain.blocks)
    )

    msgs: List[bytes] = []
    ress: List[bytes] = []
    sentLast: int = 14
    hash: bytes = bytes()
    while True:
        msgs.append(rpc.meros.recv())

        if MessageType(msgs[-1][0]) == MessageType.Syncing:
            ress.append(rpc.meros.acknowledgeSyncing())

        elif MessageType(msgs[-1][0]) == MessageType.GetBlockHash:
            height: int = int.from_bytes(msgs[-1][1 : 5], byteorder = "big")
            if height == 0:
                ress.append(rpc.meros.blockHash(merit.blockchain.last()))
            else:
                if height >= len(merit.blockchain.blocks):
                    raise Exception("Meros asked for a Block Hash we do not have.")

                ress.append(rpc.meros.blockHash(merit.blockchain.blocks[height].header.hash))

        elif MessageType(msgs[-1][0]) == MessageType.BlockHeaderRequest:
            hash = msgs[-1][1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    ress.append(rpc.meros.blockHeader(block.header))
                    break

                if block.header.hash == merit.blockchain.last():
                    raise Exception("Meros asked for a Block Header we do not have.")

        elif MessageType(msgs[-1][0]) == MessageType.BlockBodyRequest:
            hash = msgs[-1][1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    ress.append(rpc.meros.blockBody(block.body))
                    break

                if block.header.hash == merit.blockchain.last():
                    raise Exception("Meros asked for a Block Body we do not have.")

        elif MessageType(msgs[-1][0]) == MessageType.ElementRequest:
            ress.append(rpc.meros.verification(
                Verification.fromElement(
                    consensus.holders[
                        msgs[-1][1 : 49]
                    ][
                        int.from_bytes(msgs[-1][49 : 53], byteorder = "big")
                    ]
                )
            ))

        elif MessageType(msgs[-1][0]) == MessageType.TransactionRequest:
            sentLast -= 1
            ress.append(
                rpc.meros.transaction(transactions.txs[
                    msgs[-1][1 : 49]
                ])
            )

        elif MessageType(msgs[-1][0]) == MessageType.SyncingOver:
            ress.append(bytes())
            if sentLast == 0:
                break

        else:
            raise Exception("Unexpected message sent: " + msgs[-1].hex().upper())

    #Verify the height.
    if rpc.call("merit", "getHeight") != len(merit.blockchain.blocks):
        raise Exception("Height doesn't match.")

    #Verify the difficulty.
    if merit.blockchain.difficulty != int(rpc.call("merit", "getDifficulty"), 16):
        raise Exception("Difficulty doesn't match.")

    #Verify the blocks.
    for block in merit.blockchain.blocks:
        if rpc.call("merit", "getBlock", [block.header.nonce]) != block.toJSON():
            raise Exception("Block doesn't match.")

    #Verify the Transactions.
    for tx in transactions.txs:
        if rpc.call("transactions", "getTransaction", [tx.hex()]) != transactions.txs[tx].toJSON():
            raise Exception("Transaction doesn't match.")

    #Replay their messages and verify they sent what we sent.
    for m in range(0, len(msgs)):
        rpc.meros.send(msgs[m])
        if len(ress[m]) != 0:
            if ress[m] != rpc.meros.recv():
                raise Exception("Invalid sync response.")

    print("Finished the Transactions/Fifty Test.")
