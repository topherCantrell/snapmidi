'' Based on the Brilldea W5100 Web Page Demo indirect Ver. 00.1
''
''  Timothy D. Swieter, P.E.
''  Brilldea - purveyor of prototyping goods
''  www.brilldea.com
''
''  Copyright (c) 2011 Chris Cantrell
''  See end of file for terms of use.

CON

  _clkmode = xtal1 + pll16x     'Use the PLL to multiple the external clock by 16
  _xinfreq = 5_000_000          'An external clock of 5MHz. is used (80MHz. operation)

  '***************************************
  ' I/O Definitions of Spinneret Web Server Module
  '***************************************

  '~~~~Propeller Based I/O~~~~
  'W5100 Module Interface
  _WIZ_data0    = 0             'SPI Mode = MISO, Indirect Mode = data bit 0.
  _WIZ_miso     = 0
  _WIZ_data1    = 1             'SPI Mode = MOSI, Indirect Mode = data bit 1.
  _WIZ_mosi     = 1
  _WIZ_data2    = 2             'SPI Mode SPI Slave Select, Indirect Mode = data bit 2
  _WIZ_scs      = 2             
  _WIZ_data3    = 3             'SPI Mode = SCLK, Indirect Mode = data bit 3.
  _WIZ_sclk     = 3
  _WIZ_data4    = 4             'SPI Mode unused, Indirect Mode = data bit 4 
  _WIZ_data5    = 5             'SPI Mode unused, Indirect Mode = data bit 5 
  _WIZ_data6    = 6             'SPI Mode unused, Indirect Mode = data bit 6 
  _WIZ_data7    = 7             'SPI Mode unused, Indirect Mode = data bit 7 
  _WIZ_addr0    = 8             'SPI Mode unused, Indirect Mode = address bit 0 
  _WIZ_addr1    = 9             'SPI Mode unused, Indirect Mode = address bit 1 
  _WIZ_wr       = 10            'SPI Mode unused, Indirect Mode = /write 
  _WIZ_rd       = 11            'SPI Mode unused, Indirect Mode = /read 
  _WIZ_cs       = 12            'SPI Mode unused, Indirect Mode = /chip select 
  _WIZ_int      = 13            'W5100 /interrupt
  _WIZ_rst      = 14            'W5100 chip reset
  _WIZ_sen      = 15            'W5100 low = indirect mode, high = SPI mode, floating will = high.

  _DAT0         = 16
  _DAT1         = 17
  _DAT2         = 18
  _DAT3         = 19
  _CMD          = 20
  _SD_CLK       = 21
  
  _SIO          = 22            

  _LED          = 23            'UI - combo LED and buttuon
  
  _AUX0         = 24            'MOBO Interface
  _AUX1         = 25
  _AUX2         = 26
  _AUX3         = 27

  'I2C Interface
  _I2C_scl      = 28            'Output for the I2C serial clock
  _I2C_sda      = 29            'Input/output for the I2C serial data  

  'Serial/Programming Interface (via Prop Plug Header)
  _SERIAL_tx    = 30            'Output for sending misc. serial communications via a Prop Plug
  _SERIAL_rx    = 31            'Input for receiving misc. serial communications via a Prop Plug

  '***************************************
  ' I2C Definitions
  '***************************************
  _EEPROM0_address = $A0        'Slave address of EEPROM  

  _bytebuffersize = 2048

'**************************************
VAR    

  'Configuration variables for the W5100
  byte  MAC[6]                  '6 element array contianing MAC or source hardware address ex. "02:00:00:01:23:45"
  byte  Gateway[4]              '4 element array containing gateway address ex. "192.168.0.1"
  byte  Subnet[4]               '4 element array contianing subnet mask ex. "255.255.255.0"
  byte  IP[4]                   '4 element array containing IP address ex. "192.168.0.13"

  'verify variables for the W5100
  byte  vMAC[6]                 '6 element array contianing MAC or source hardware address ex. "02:00:00:01:23:45"
  byte  vGateway[4]             '4 element array containing gateway address ex. "192.168.0.1"
  byte  vSubnet[4]              '4 element array contianing subnet mask ex. "255.255.255.0"
  byte  vIP[4]                  '4 element array containing IP address ex. "192.168.0.13"
  
  long  localSocket             '1 element for the socket number

  'Variables to info for where to return the data to
  byte  destIP[4]               '4 element array containing IP address ex. "192.168.0.16"
  long  destSocket              '1 element for the socket number

  'Misc variables
  byte  data[_bytebuffersize]
  'long  stack[50]                    

OBJ               

  ETHERNET   :   "W5100_Indirect_Driver.spin"
  
PUB init | temp0 
    
  'Start the W5100 driver
  ETHERNET.StartINDIRECT(_WIZ_data0, _WIZ_addr0, _WIZ_addr1, _WIZ_cs, _WIZ_rd, _WIZ_wr,  _WIZ_rst, _WIZ_sen)
   
  'MAC ID to be assigned to W5100  
  MAC[0] := $00
  MAC[1] := $08
  MAC[2] := $DC 
  MAC[3] := $16 
  MAC[4] := $F0 
  MAC[5] := $16 

  'Subnet address to be assigned to W5100
  Subnet[0] := 255
  Subnet[1] := 255
  Subnet[2] := 255
  Subnet[3] := 0

  'IP address to be assigned to W5100
  IP[0] := 192
  IP[1] := 168
  IP[2] := 1
  IP[3] := 120

  'Gateway address of the system network
  Gateway[0] := 192
  Gateway[1] := 168
  Gateway[2] := 1
  Gateway[3] := 1
  
  'Local socket
  localSocket := 80 

  'Destination IP address - can be left zeros, the TCO demo echoes to computer that sent the packet
  destIP[0] := 0
  destIP[1] := 0
  destIP[2] := 0
  destIP[3] := 0 
  destSocket := 0  
   
  'Set the W5100 addresses
  SetVerifyMAC(@MAC[0])
  SetVerifyGateway(@Gateway[0])
  SetVerifySubnet(@Subnet[0])
  SetVerifyIP(@IP[0])

  ETHERNET.InitSocketMem(0)


PUB getConnection

  ETHERNET.SocketOpen(0, ETHERNET#_TCPPROTO, localSocket, destSocket, @destIP[0])

  'Wait a moment for the socket to get established
  PauseMSec(500)
    
  ETHERNET.SocketTCPlisten(0)

  'Wait a moment for the socket to listen
  PauseMSec(500)

  ' Wait for a connection
  repeat while !ETHERNET.SocketTCPestablished(0) 
    
PUB getPacket(numReadPtr) | packetSize     

  'Initialize the buffers and bring the data over
  bytefill(@data, 0, _bytebuffersize)
    
  repeat
    if !ETHERNET.SocketTCPestablished(0)
      return 0
    packetSize := ETHERNET.rxTCP(0, @data)
  while packetSize == 0

  long[numReadPtr] := packetSize  ' Return the number of bytes read
  return @data

PUB getSocketStatus | temp0
  ETHERNET.readIND(ETHERNET#_S0_SR, @temp0, 1)
  return temp0

PUB disconnectSocket
  ETHERNET.SocketTCPdisconnect(0)

PUB closeSocket
  ETHERNET.SocketClose(0)  

PUB openSocketAndListen
  ETHERNET.SocketOpen(0, ETHERNET#_TCPPROTO, localSocket, destSocket, @destIP[0])
  ETHERNET.SocketTCPlisten(0)
    
PRI SetVerifyMAC(_firstOctet) 
  ETHERNET.WriteMACaddress(true, _firstOctet)
  PauseMSec(500)  
  return

PRI SetVerifyGateway(_firstOctet) 
  ETHERNET.WriteGatewayAddress(true, _firstOctet)  
  PauseMSec(500)      
  return 

PRI SetVerifySubnet(_firstOctet)
  ETHERNET.WriteSubnetMask(true, _firstOctet) 
  PauseMSec(500)
  return
  
PRI SetVerifyIP(_firstOctet)  
  ETHERNET.WriteIPAddress(true, _firstOctet) 
  PauseMSec(500) 
  return                 
  
PUB StringSend(_dataPtr)  
  ETHERNET.txTCP(0,_dataPtr, strsize(_dataPtr)) 
  return 
 
PUB txTCP(b,c)
  return ETHERNET.txTCP(0,b,c)    

PUB PauseMSec(Duration)  

''  Pause execution for specified milliseconds.
''  This routine is based on the set clock frequency.
''  
''  params:  Duration = number of milliseconds to delay                                                                                               
''  return:  none
  
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> 381) + cnt)

  return

DAT
'*************************************** 

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}