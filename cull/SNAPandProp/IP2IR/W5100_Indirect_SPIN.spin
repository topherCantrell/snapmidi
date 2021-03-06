{{
 The WIZNet has three physical connection modes.

 In SPI mode the connection is serial, which is slower but consumes fewer I/O pins.

 In Direct-Bus mode the chip connects to the processor's Address/data bus with 8 data pins
 and 15 address pins. This is the fastest way to talk to the WIZNet's internal memory, but
 it consumes a lot of I/O pins.

 The Indirect-Bus mode connects to the processor's Address/data bus with 8 data pins
 and only 2 address pins. The CPU then accesses the WIZNet's internal memory by
 writing the MSB to address 1 and the LSB to address 2. The actual data is then read/written
 from address 3. This is slower than a "direct-bus" connection, but consumes 14 fewer
 precious I/O pins.

 For instance, to increment the value in the WIZNet's memory $1234 you would do the following:
 - Write $12 to address 1
 - Write $34 to address 2
 - Read value from address 3
 - Increment value
 - Write $12 to address 1
 - Write $34 to address 2
 - Write new value to address 3

 In "direct-bus" mode, these "indirect address/data" are not needed. In fact, addresses 1, 2,
 and 3 are used for other things. To enable these indirect registers you must turn on a bit
 in register 0. How can you write to the mode register when you have to have the indirect
 function turned on to access any register?

 Address 0 in Direct and Indirect bus mode both access the mode register. This allows you to
 turn on the indirect features by setting bit 0 in the mode register. After that you can access
 the mode register the "long" way by writing 0 to address 1 and 2 and then reading address 3. or
 you can go the "short" way an read address 0, which will always be the mode register.

 Many times you want to access WIZNet memory sequentially. It is inefficient to write the incremented
 address each time. You can turn on an "auto-increment" bit in the mode register and the hardware
 will increment the address registers (1 and 2) for you after each access. You write the MSB and
 LSB of the first address and then just read or write the data register (address 3) over and over.

 To summarize:
 In direct-bus mode you access the WIZNet memory directly through the address/data bus.
 In indirect-bus mode you access the WIZNet memory indirectly through four addresses on the
 address/data bus:
   00 Mode Register
   01 MSB Address Register (write first)
   10 LSB Address Register (write second)
   11 Data Register (read or write)
}}

PUB PauseMSec(Duration)
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> 381) + cnt)
  return
  
PUB initINDIRECT(_WIZ_addr0, _WIZ_addr1, _WIZ_cs, _WIZ_rd, _WIZ_wr, _WIZ_rst, _WIZ_data0, _WIZ_SEN) | t
'
'' This function initializes the I/O pins for indirect-bus connection with the W5100 chip.
'' The WIZ mode register is set to indirect-bus and the auto-increment mode is turned on.
      
  ADD0mask  := |< _WIZ_addr0
  ADD1mask  := |< _WIZ_addr1
  CSmask    := |< _WIZ_cs
  RDmask    := |< _WIZ_rd
  WRmask    := |< _WIZ_wr
  RESETmask := |< _WIZ_rst

  BASEpin   := _WIZ_data0                                'The base pin of data byte for shifting operations
  DATAmask  := %1111_1111 << _WIZ_data0                  'Special mask setup with eight pins

  WRCSmask  := WRmask | CSmask
  RDCSmask  := RDmask | CSmask
  WRRDCSmask:= WRmask | RDmask | CSmask

  if _WIZ_sen <> -1
    SENmask := |< _WIZ_sen
  else
    SENmask := 0

  ' ----------------------------------------------------------------------    
 outa :=  CSmask          'W5100 Chip Select is initialized as high
 outa |=  RDmask          'W5100 Read cmd is initialized as high
 outa |=  WRmask          'W5100 Write cmd is initialized as high

 'Remaining outputs initialized as low including reset
 'NOTE: the W5100 is held in reset because the pin is low

 'Next set up the I/O with the masks in the direction register
 'all outputs pins are set up here because input is the default state
 dira := ADD0mask        'Set to an output and clears cog dira register
 dira |= ADD1mask        'Set to an output
 dira |= CSmask          'Set to an output
 dira |= RDmask          'Set to an output
 dira |= WRmask          'Set to an output
 dira |= RESETmask       'Set to an output
 dira |= DATAmask        'Set to an output
 dira |= SENmask         'Set to an output

 outa |= RESETmask       ' Finally - make the reset line high for the W5100 to come out of reset
 
 PauseMSec(500)            ' Short wait for reset
 
 WriteWIZMode(%000000_11)  ' Auto-increment on and use IND mode

PUB WriteWIZMode(data)
'
'' This function writes an 8-bit value to the WIZNet's mode register (address 0).
'' @data the value to write to register 0

  dira |= DATAmask        'Ensure data pins are outputs

  outa &= (!ADD0mask)     'Set Address to %00 - Mode Register access
  outa &= (!ADD1mask)

  data := data & $FF      'Prepare the data, ensure there is only a byte in the data
  data := data << BASEpin 'Move the data over so it is in the correct spot for copying to outa

  outa &= (!DATAmask)     'Clear the data pins in outa
  outa |= data            'Set the new data in outa

  outa &= (!WRCSmask)     'Clear the WR and CS bits - W5100 reads the data
  outa |= WRRDCSmask      'Turn on WR, RD, and CS bits - end of transaction

PUB WriteWIZRegister(address, data)
'
'' This function writes a value to the targeted WIZNet memory address.
'' @address the WIZNet memory address
'' @data the data to write
                                                                               
  writeWIZAddress(address)

  dira |= DATAmask        'Ensure data pins are outputs
  outa |= ADD0mask        'Set Address to %11 - Data Register access
  outa |= ADD1mask

  data := data << BASEpin 'Move the data over so it is in the correct spot for copying to outa

  outa &= (!DATAmask)     'Clear the data pins in outa
  outa |= data            'Set the new data in outa
  
  outa &= (!WRCSmask)     'Clear the WR and CS bits - W5100 reads the data
  outa |= WRRDCSmask      'Turn on WR, RD, and CS bits - end of transaction

PUB WriteWIZMulti(startAddress, source, size) | data, c
'
'' This function writes a series of values to sequential WIZNet memory addresses.
'' @startAddress the first WIZNet memory address
'' @source pointer to the first byte of data to copy
'' @size number of bytes to copy

  writeWIZAddress(startAddress)

  dira |= DATAmask        'Ensure data pins are outputs
  outa |= ADD0mask        'Set Address to %11 - Data Register access
  outa |= ADD1mask

  repeat c from 1 to size

    data := byte[source++] 

    data := data << BASEpin 'Move the data over so it is in the correct spot for copying to outa

    outa &= (!DATAmask)     'Clear the data pins in outa
    outa |= data            'Set the new data in outa
  
    outa &= (!WRCSmask)     'Clear the WR and CS bits - W5100 reads the data
    outa |= WRRDCSmask      'Turn on WR, RD, and CS bits - end of transaction    

PUB ReadWIZRegister(address) | data
'
'' This function reads a value from the targeted WIZNet memory address.
'' @address the WIZNet memory address
'' @return the value from memory

  writeWIZAddress(address)    ' Set the address

  dira &= (!DATAmask)     'Ensure data pins are inputs
  outa |= ADD0mask        'Set Address to %11 - Data Register access
  outa |= ADD1mask

  outa &= (!RDCSmask)     'Clear the RD and CS bits
  outa &= (!RDCSmask)     ' Kill ...
  outa &= (!RDCSmask)     ' ... time  

  data := ina             'Copy data from ina
  outa |= WRRDCSmask      'Turn on WR, RD, and CS bits
  data := data >> BASEPin 'Move the byte to the lowest byte
  data := data & $FF      'Finalize the data to have only the lowest byte

  return data  

PUB ReadWIZMulti(startAddress, dest, size) | data, c
'
'' This function reads a series of values from sequential WIZNet memory addresses.
'' @startAddress the first WIZNet memory address
'' @dest pointer to the first byte of data to copy
'' @size number of bytes to copy

  writeWIZAddress(startAddress)
  
  dira &= (!DATAmask)     'Ensure data pins are inputs
  outa |= ADD0mask        'Set Address to %11 - Data Register access
  outa |= ADD1mask

  repeat c from 1 to size
  
    outa &= (!RDCSmask)     'Clear the RD and CS bits
    outa &= (!RDCSmask)     ' Kill ...
    outa &= (!RDCSmask)     ' ... time  

    data := ina             'Copy data from ina
    outa |= WRRDCSmask      'Turn on WR, RD, and CS bits
    data := data >> BASEPin 'Move the byte to the lowest byte
    data := data & $FF      'Finalize the data to have only the lowest byte

    byte[dest++] := data

PUB writeWIZAddress(reg) | t1
'
'' This function writes the LSB and MSB of the targeted WIZNet address to the
'' indirect-bus address registers.
'' @reg the WIZNet address to be accessed later
  
  dira |= DATAmask      ' Ensure data pins are outputs

  outa |= ADD0mask      ' Set Address to %01 - MSB address Register access
  outa &= (!ADD1mask)

  t1 := reg & $FF00     ' Upper byte 
  t1 := t1 >> 8         ' Right justify the byte
  t1 := t1 << BASEPin   ' Move the byte to the data lines

  outa &= (!DATAmask)   ' Clear the data pins in outa
  outa |= t1            ' Set the MSB address in outa

  outa &= (!WRCSmask)   ' Clear the WR and CS bits - W5100 reads the data 
  outa |= WRRDCSmask    ' Turn on WR, RD, and CS bits - end of transaction

  'LSB address byte
  outa &= (!ADD0mask)   ' Set Address to %10 - LSB address Register access
  outa |= ADD1mask

  t1 := reg & $FF       ' Lower byte
  t1 := t1 << BASEPin   ' Move the byte to the data lines

  outa &= (!DATAmask)   ' Clear the data pins in outa
  outa |= t1            ' Set the LSB address in outa

  outa &= (!WRCSmask)   ' Clear the WR and CS bits - W5100 reads the data
  outa |= WRRDCSmask    ' Turn on WR, RD, and CS bits - end of transaction  

DAT

'Pin/mask definitions 
ADD0mask      long      0-0     'W5100 Address[0] - output
ADD1mask      long      0-0     'W5100 Address[1] - output
CSmask        long      0-0     'W5100 Chip Select - active low, output
RDmask        long      0-0     'W5100 Read cmd - active low, output
WRmask        long      0-0     'W5100 Write cmd - active low, output
RESETmask     long      0-0     'W5100 Reset - active low, output

BASEpin       long      0-0     'Base pin of data byte for shifting operation
DATAmask      long      0-0     'W5100 Data[0] to [7] - output/input

WRCSmask      long      0-0     'Various combinations of masks for the CS, RD, and WR pins for ...
RDCSmask      long      0-0     '... expidited processing in ASM routine 
WRRDCSmask    long      0-0     '

SENmask       long      0-0     'W5100 SPI Enable 0 output, low = indirect/parallel, high = SPI
  