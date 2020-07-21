import algorithm
import sequtils
import os

version     = "0.6.0"
author      = "Luke Parker"
description = "Meros Cryptocurrency"
license     = "MIT"

binDir =  "build"
bin =     @["Meros"]
srcDir =  "src"
skipExt = @["nim"]

#Dependencies.
requires "nim >= 1.2.4"
requires "https://github.com/MerosCrypto/Argon2 >= 1.1.2"
requires "https://github.com/MerosCrypto/mc_randomx >= 0.9.4"
requires "https://github.com/MerosCrypto/mc_bls >= 2.0.8"
requires "https://github.com/MerosCrypto/mc_ed25519 >= 1.0.1"
requires "https://github.com/MerosCrypto/mc_minisketch >= 0.8.5"
requires "https://github.com/MerosCrypto/mc_lmdb >= 2.0.0"
requires "https://github.com/MerosCrypto/mc_webview >= 0.1.1"
requires "https://github.com/MerosCrypto/Nim-MerosRPC >= 2.1.4"
requires "https://github.com/kayabaNerve/ForceCheck >= 1.3.2"
requires "nimcrypto >= 0.4.11"
requires "normalize >= 0.7.1"
requires "stint >= 0.0.1"
requires "chronicles >= 0.8.1"
requires "https://github.com/status-im/nim-chronos >= 2.3.9"

#Procedures.
proc gatherTestFiles(
  dir: string
): seq[string] =
  var files: seq[string] = newSeq[string]()
  for f in listFiles(dir):
    let file: tuple[dir, name, ext: string] = splitFile(f)
    if file.name.endsWith("Test") and file.ext == ".nim":
      files.add(f)
  for d in listDirs(dir):
    files &= gatherTestFiles(d)
  return files

proc nimbleExec(
  command: string
) =
  let nimbleExe: string = system.findExe("nimble")
  if nimbleExe == "":
    echo "Failed to find executable `nimble`."
    quit(1)

  exec nimbleExe & " " & command

proc nimExec(
  command: string
) =
  let nimExe: string = system.findExe("nim")
  if nimExe == "":
    echo "Failed to find executable `nim`."
    quit(1)

  exec nimExe & " " & command

let
  buildDir: string = thisDir() / "build"
  testWorkingDir: string = buildDir / "tests"
  testsDir: string = thisDir() / "tests"

#Tasks.
task clean, "Clean all build files.":
  rmDir projectDir() / "build"

task build, "Build Meros.":
  setCommand "nop"

task install, "Install Meros.":
  setCommand "nop"

task unit, "Run unit/integration tests.":
  #Gather parameters to pass to `nim c -r ...`.
  var additionalParams: seq[string] = newSeq[string]()
  for i in countdown(system.paramCount(), 1):
    var v: string = system.paramStr(i)
    if v == "unit":
      break
    additionalParams.add(v)

  var params: string =
    additionalParams
      .reversed()
      .map(
        proc (
          x: string
        ): string =
          "\"" & x & "\""
      )
      .join(" ")

  #Ensure dependencies are installed.
  nimbleExec "install --depsOnly"

  #Create a single test file will all test imports.
  var contents: string = "{.warning[UnusedImport]: off.}\n\n"
  for f in gatherTestFiles(testsDir):
    contents &= "import ../../tests" & f.replace(testsDir).changeFileExt("") & "\n"
  mkDir testWorkingDir
  let allTestsFile: string = testWorkingDir / "AllTests.nim"
  allTestsFile.writeFile(contents)

  #Copy config.
  cpFile(projectDir() / "tests" / "config.nims",  testWorkingDir / "config.nims")

  #Execute tests.
  nimExec "c -r " & allTestsFile & " " & params

task e2e, "Run end-to-end tests.":
  #TODO: setup and run `e2e`.
  echo "Not yet implemented."

task test, "Run all tests.":
  nimbleExec "unit"
  nimbleExec "e2e"

task ci, "Run CI tasks.":
  nimbleExec "clean"

  mkDir testWorkingDir
  cpFile(projectDir() / "tests" / "ci.cfg", testWorkingDir / "nim.cfg")
  defer: rmFile testWorkingDir / "nim.cfg"
  nimbleExec "unit"

  nimbleExec "e2e"
