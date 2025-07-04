@echo off
msbuild build\Cloud-sim.sln
mv build\bin\Release\Cloud-sim.exe build\cs.exe
start cmd /k .\Build\cs.exe
