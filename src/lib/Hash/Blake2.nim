import ../Errors
import ../Util

import HashCommon

#C API which is used solely for Blake2b-64.
const currentFolder: string = currentSourcePath().substr(0, currentSourcePath().len - 11)
#We don't compile in Blake2b as it's already compiled in via one of our dependent packages.
#{.compile: currentFolder & "Blake2/blake2b-ref.c".}

{.passC: "-I" & currentFolder & "Blake2/"}
{.push, header: "blake2.h".}
type Blake2bState {.importc: "blake2b_state".} = object
proc init(
  state: ptr Blake2bState,
  bytes: int
): cint {.importc: "blake2b_init".}
proc update(
  state: ptr Blake2bState,
  data: pointer,
  len: int
): cint {.importc: "blake2b_update".}
proc finalize(
  state: ptr Blake2bState,
  output: pointer,
  len: int
): cint {.importc: "blake2b_final".}
{.pop.}

proc Blake[bits: static int](
  bytes: string
): Hash[bits] {.forceCheck: [].} =
  var
    dataPtr: ptr char
    state: ptr Blake2bState = cast[ptr Blake2bState](alloc0(sizeof(Blake2bState)))
  if bytes.len != 0:
    dataPtr = unsafeAddr bytes[0]

  if state.init(bits div 8) != 0:
    panic("Failed to init a " & $(bits div 8) & "-byte Blake2b State.")
  if state.update(dataPtr, bytes.len) != 0:
    panic("Failed to update a Blake2b State.")

  if state.finalize(addr result.data[0], bits div 8) != 0:
    panic("Failed to finalize a Blake2b State.")

  dealloc(state)

proc Blake2_64*(
  bytes: string
): uint64 {.inline, forceCheck: [].} =
  uint64(Blake[64](bytes).serialize().fromBinary())

proc Blake2_256*(
  bytes: string
): Hash[256] {.inline, forceCheck: [].} =
  Blake[256](bytes)

proc Blake2_512*(
  bytes: string
): Hash[512] {.inline, forceCheck: [].} =
  Blake[512](bytes)
