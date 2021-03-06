{{
 SD2.0 FATEngine Wrapper
 by Roy Eltham
 11/18/2010
 Copyright (c) 2010 Roy Eltham
 See end of file for terms of use.
}}

CON
  _clkfreq = 80_000_000
  _clkmode = xtal1 + pll16x

  _cardDataOutPin = 16
  _cardClockPin = 21
  _cardDataInPin = 20
  _cardChipSelectPin = 19

OBJ
  fat: "SD2.0_FATEngine.spin"
 
PUB Start
  fat.FATEngineStart(_cardDataOutPin, _cardClockPin, _cardDataInPin, _cardChipSelectPin, 0, 0)
                                                                                                                               
PUB checkError
  return fat.checkErrorNumber

PUB mount(stringPointer)
  return fat.mountPartition(0, stringPointer)
 
PUB unmount(stringPointer)
  return fat.unmountPartition

PUB changeDirectory(directoryName)
  return fat.changeDirectory(directoryName)

PUB getWorkingDirectory
  return fat.listWorkingDirectory

PUB startFindFile
  fat.listName("T")

PUB nextFindFile | temp, index  
  temp := fat.listName(" ")
  repeat index from 0 to 11
    if byte[temp][index] == 32
       byte[temp][index] := 0
       quit
  return temp

PUB openFile(fileName, action)
  return fat.openFile(fileName, action)

PUB closeFile
  return fat.closeFile

PUB getFileSize
  return fat.listSize
  
PUB readFromFile(bufferPtr, bufferSize)
  return fat.readData(bufferPtr, bufferSize)


PUB flushData
  fat.flushData

PUB deleteEntry(name)
  return fat.deleteEntry(name)

PUB newFile(fileName)
  return fat.newFile(fileName)

PUB writeData(addressToGet, count)
  return fat.writeData(addressToGet, count)

  
PUB checkFilePosition '' 3 Stack Longs
  return  fat.checkFilePosition

PUB changeFilePosition(position)
  return changeFilePosition(position)

PUB writeByte(value)
  return fat.writeByte(value)

     
{{
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                 │                                                            
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation   │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,   │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the        │
│Software is furnished to do so, subject to the following conditions:                                                         │         
│                                                                                                                             │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the         │
│Software.                                                                                                                    │
│                                                                                                                             │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE         │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR        │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,  │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                        │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}                        