#State Value Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Miners object.
import ../../../../src/Database/Merit/objects/MinersObj

#Difficulty, Block, Blockchain, and State libs.
import ../../../../src/Database/Merit/Difficulty
import ../../../../src/Database/Merit/Block
import ../../../../src/Database/Merit/Blockchain
import ../../../../src/Database/Merit/State

#Merit Testing lib.
import ../TestMerit

#Compare Merit lib.
import ../CompareMerit

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #Database.
        db: DB = newTestDatabase()
        #Blockchain.
        blockchain: Blockchain = newBlockchain(
            db,
            "STATE_TEST",
            30,
            "".pad(48).toHash(384)
        )
        #State.
        state: State = newState(
            db,
            5,
            blockchain.height
        )
        #List of MeritHolders.
        holders: seq[MinerWallet] = @[
            newMinerWallet(char(0).pad(48)),
            newMinerWallet(char(1).pad(48)),
            newMinerWallet(char(2).pad(48)),
            newMinerWallet(char(3).pad(48))
        ]
        #Miners we're mining to.
        miners: seq[seq[Miner]] = @[
            @[
                newMinerObj(
                    holders[0].publicKey,
                    100
                )
            ],
            @[
                newMinerObj(
                    holders[0].publicKey,
                    30
                ),
                newMinerObj(
                    holders[1].publicKey,
                    70
                )
            ],
            @[
                newMinerObj(
                    holders[0].publicKey,
                    50
                ),
                newMinerObj(
                    holders[1].publicKey,
                    40
                ),
                newMinerObj(
                    holders[2].publicKey,
                    10
                )
            ],
            @[
                newMinerObj(
                    holders[0].publicKey,
                    20
                ),
                newMinerObj(
                    holders[1].publicKey,
                    30
                ),
                newMinerObj(
                    holders[2].publicKey,
                    40
                ),
                newMinerObj(
                    holders[3].publicKey,
                    10
                )
            ],
            @[
                newMinerObj(
                    holders[1].publicKey,
                    50
                ),
                newMinerObj(
                    holders[2].publicKey,
                    50
                )
            ],
            @[
                newMinerObj(
                    holders[1].publicKey,
                    100
                )
            ],
            @[
                newMinerObj(
                    holders[2].publicKey,
                    100
                )
            ],
            @[
                newMinerObj(
                    holders[1].publicKey,
                    25
                ),
                newMinerObj(
                    holders[2].publicKey,
                    25
                ),
                newMinerObj(
                    holders[3].publicKey,
                    50
                )
            ],
            @[
                newMinerObj(
                    holders[1].publicKey,
                    40
                ),
                newMinerObj(
                    holders[2].publicKey,
                    10
                ),
                newMinerObj(
                    holders[3].publicKey,
                    50
                )
            ],
            @[
                newMinerObj(
                    holders[0].publicKey,
                    100
                )
            ],
        ]
        #Miner to remove the Merit of.
        toRemove: seq[int] = @[
            0,
            0,
            1,
            3,
            -1,
            -1,
            -1,
            1,
            2,
            -1
        ]
        #State Values.
        values: seq[seq[int]] = @[
            @[
                0,
                0,
                0,
                0
            ],
            @[
                0,
                70,
                0,
                0
            ],
            @[
                50,
                0,
                10,
                0
            ],
            @[
                70,
                30,
                50,
                0
            ],
            @[
                70,
                80,
                100,
                0
            ],
            @[
                70,
                180,
                100,
                0
            ],
            @[
                70,
                180,
                200,
                0
            ],
            @[
                20,
                0,
                215,
                50
            ],
            @[
                0,
                40,
                0,
                100
            ],
            @[
                100,
                40,
                0,
                100
            ]
        ]
        #Block we're mining.
        mining: Block

    #Iterate over 10 'rounds'.
    for i in 0 ..< 10:
        #Create the Block.
        mining = newBlankBlock(
            nonce = blockchain.height,
            last = blockchain.tip.header.hash,
            miners = newMinersObj(miners[i])
        )
        #Mine it.
        while not blockchain.difficulty.verify(mining.header.hash):
            inc(mining)

        #Add it to the Blockchain.
        blockchain.processBlock(mining)

        #Add it to the State.
        state.processBlock(blockchain, mining)

        #Remove Merit from the specified MeritHolder.
        if toRemove[i] != -1:
            state.remove(holders[toRemove[i]].publicKey, mining)

        #Commit the DB.
        db.commit(mining.nonce)

        #Verify the State
        for v in 0 ..< 4:
            assert(state[holders[v].publicKey] == values[i][v])

    echo "Finished the Database/Merit/State/Value Test."
