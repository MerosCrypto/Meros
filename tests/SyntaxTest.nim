#Syntax test. Compiles every file to verify the codebase has valid syntax.

#Lib.
import ../src/lib/Errors
import ../src/lib/Util
import ../src/lib/Logger

import ../src/lib/Base
import ../src/lib/Base32

import ../src/lib/BLS

import ../src/lib/libsodium
import ../src/lib/ED25519

import ../src/lib/Hash
import ../src/lib/Merkle

#Wallet.
import ../src/Wallet/Wallet

#Database.
import ../src/Database/Filesystem/Filesystem
import ../src/Database/Lattice/Lattice
import ../src/Database/Merit/Merit

#Network.
import ../src/Network/Serialize/SerializeCommon

import ../src/Network/Serialize/SerializeMiners
import ../src/Network/Serialize/SerializeBlock

import ../src/Network/Serialize/SerializeMint
import ../src/Network/Serialize/SerializeClaim
import ../src/Network/Serialize/SerializeSend
import ../src/Network/Serialize/SerializeReceive
import ../src/Network/Serialize/SerializeData
import ../src/Network/Serialize/SerializeVerification
import ../src/Network/Serialize/SerializeMeritRemoval

import ../src/Network/Serialize/ParseMiners
import ../src/Network/Serialize/ParseBlock

import ../src/Network/Serialize/ParseMint
import ../src/Network/Serialize/ParseClaim
import ../src/Network/Serialize/ParseSend
import ../src/Network/Serialize/ParseReceive
import ../src/Network/Serialize/ParseData
import ../src/Network/Serialize/ParseVerification
import ../src/Network/Serialize/ParseMeritRemoval

import ../src/Network/Network

#UI.
import ../src/UI/UI
