CON

  _clkmode = xtal1 + pll16x     'Use the PLL to multiple the external clock by 16
  _xinfreq = 5_000_000          'An external clock of 5MHz. is used (80MHz. operation)

  '~~~~Spinneret I/O pins~~~~
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
 
OBJ

  WIZ    : "W5100_Indirect_SPIN.spin"
  WZC    : "W5100_CONST.spin"
  PST    : "Parallax Serial Terminal.spin"

VAR

 byte tmp[6]
   
PUB main | t, old

  WIZ.PauseMSec(2_000)     'A small delay to allow time to switch to the terminal application after loading the device
  
  PST.Start(115_200) 
  PST.Home
  PST.Clear
  PST.Str(string("Started.",13))

  WIZ.initINDIRECT(_WIZ_addr0, _WIZ_addr1, _WIZ_cs, _WIZ_rd, _WIZ_wr, _WIZ_rst, _WIZ_data0, _WIZ_SEN)     

  ' Gateway (192.168.1.1)  Address of my router
  ' (Demonstrating single-register writes)
  WIZ.WriteWIZRegister(WZC#_GAR0,192)
  WIZ.WriteWIZRegister(WZC#_GAR1,168)
  WIZ.WriteWIZRegister(WZC#_GAR2,1)
  WIZ.WriteWIZRegister(WZC#_GAR3,1)

  ' Subnet (255.255.255.0)
  tmp[0] := 255
  tmp[1] := 255
  tmp[2] := 255
  tmp[3] := 0
  WIZ.WriteWIZMulti(WZC#_SUBR0,@tmp,4)
 
  ' MAC (00:08:DC:16:F0:16) Printed on bottom of board
  tmp[0] := $00
  tmp[1] := $08
  tmp[2] := $DC
  tmp[3] := $16
  tmp[4] := $F0
  tmp[5] := $16
  WIZ.WriteWIZMulti(WZC#_SHAR0,@tmp,6)

  ' Source IP (192.168.1.120)
  tmp[0] := 192
  tmp[1] := 168
  tmp[2] := 1
  tmp[3] := 120
  WIZ.WriteWIZMulti(WZC#_SIPR0,@tmp,4)
  
  WIZ.PauseMSec(1_000)

  
  ' START 
  WIZ.WriteWIZRegister(WZC#_S0_MR,WZC#_TCPPROTO) ' One bit ... all else 0s on purpose
  WIZ.WriteWIZRegister(WZC#_S0_PORT1,0)
  WIZ.WriteWIZRegister(WZC#_S0_PORT1,80)
  WIZ.WriteWIZRegister(WZC#_S0_CR,WZC#_OPEN)
  {
  t := WIZ.ReadWIZRegister(WZC#_S0_SR)
  if t<>WZC#_SOCK_INIT    
    WIZ.WriteWIZRegister(WZC#_S0_CR,WZC#_CLOSE)
    goto start
  }

  'WIZ.WriteWIZRegister(WZC#_S0_CR,WZC#_LISTEN)
  {
  t := WIZ.ReadWIZRegister(WZC#_S0_SR)
  if t<>WZC#_SOCK_LISTEN    
    WIZ.WriteWIZRegister(WZC#_S0_CR,WZC#_CLOSE)
    goto start
  }

  ' Print changes in status register
  old := -1
  repeat
    WIZ.ReadWIZRegister(WZC#_S0_SR)
    if t<>old
      PST.hex(t,2)
      PST.str(string(" "))
      old := t

