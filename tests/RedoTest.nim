#Run every working Test...

import objectsTests
import libTests
import WalletTests

import DatabaseTests/FilesystemTests

import DatabaseTests/ConsensusTests/VerificationTest
# import DatabaseTests/ConsensusTests/MeritHolder
# import DatabaseTests/ConsensusTests/ConsensusTest

import DatabaseTests/MeritTests/BlockHeaderTest
import DatabaseTests/MeritTests/BlockTest
import DatabaseTests/MeritTests/DifficultyTest
import DatabaseTests/MeritTests/BlockchainTests
import DatabaseTests/MeritTests/StateTests
# import DatabaseTests/MeritTests/EpochTests
import DatabaseTests/MeritTests/MeritTest

import UITests
import NetworkTests

echo "Finished all the Tests."
