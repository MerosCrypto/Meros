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

import ../src/Network/Serialize/Merit/SerializeVerifications
import ../src/Network/Serialize/Merit/SerializeMiners
import ../src/Network/Serialize/Merit/SerializeBlock

import ../src/Network/Serialize/Lattice/SerializeMint
import ../src/Network/Serialize/Lattice/SerializeClaim
import ../src/Network/Serialize/Lattice/SerializeSend
import ../src/Network/Serialize/Lattice/SerializeReceive
import ../src/Network/Serialize/Lattice/SerializeData
import ../src/Network/Serialize/Lattice/SerializeMeritRemoval

import ../src/Network/Serialize/Merit/ParseVerifications
import ../src/Network/Serialize/Merit/ParseMiners
import ../src/Network/Serialize/Merit/ParseBlock

import ../src/Network/Serialize/Lattice/ParseMint
import ../src/Network/Serialize/Lattice/ParseClaim
import ../src/Network/Serialize/Lattice/ParseSend
import ../src/Network/Serialize/Lattice/ParseReceive
import ../src/Network/Serialize/Lattice/ParseData
import ../src/Network/Serialize/Lattice/ParseMeritRemoval

import ../src/Network/Network

#UI.
import ../src/UI/UI
