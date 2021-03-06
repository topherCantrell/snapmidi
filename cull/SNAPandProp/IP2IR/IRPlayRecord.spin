{{
 IRPlayRecord 
 by Chris Cantrell
 Version 1.1 6/27/2011
 Copyright (c) 2011 Chris Cantrell
 See end of file for terms of use.
}}

{{

  IRPlayRecord

  This object records and plays-back 38KHz PWM IR Remote samples.
             
  For the GP1UX311QS IR sensor. See:
  http://www.ladyada.net/learn/sensors/ir.html   
                 
                      +5
                IR    
          120   ┌─┘ 120
  POUT ─────    
                │  2N3904G
                

          ┌───┐ GP1UX311QS
          │ ° │
          └┬┬┬┘ +5    
           │││  
  PIN  ───┘└──┘              

  This driver runs in a COG and watches a command block for command requests.
    command  - non-zero command value. Returns to zero when the command is done
    param    - additional parameters needed by some commands. Returns non-zero error status.
    bufPtr   - pointer to buffer used by command

  At startup the "param" must contain the I/O pin configuration: OUT<<8 | IN.
    For example, my project has pin 0 connected to the sensor and pin 7 connected to the LED outputs.
    I initialized the driver with "7<<8 | 0".

  Command "1" : Record IR sequence
    This command fills a buffer (pointed to by bufPtr) with pulse transition timing values.
    Before the command starts the first word of the buffer must contain the max number of
    bytes allowed to be written. When the command is complete the first word of the buffer
    contains the actual number of bytes written.

  Command "2" : Play IR sequence
    This command plays out a buffer (pointed to by bufPtr) of previously recorded IR samples.
    The first word of this buffer contains the number of bytes to play.
}}
                          
CON

' For clock config of "xtal1 + pll16x" and a 5_000_000 crystal:
' Clock runs at 80_000_000Hz.
' 80_000_000 * 0.000_010 = 800 clocks
' Thus a wait count of +800 is 10usecs
' The written sample values are numbers of 10usec intervals
  resolution = 800

' 65 ms is 65/.01 = 6500 10-usec-intervals
  maxPulse = 6500

VAR  
  long  cog          

PUB start(data) : okay

'' Start IRSensor driver - starts a cog
'' returns false if no cog available      ''

  stop
  okay := cog := cognew(@entry, data) + 1


PUB stop

'' Stop IR Sensor - frees a cog

  if cog
    cogstop(cog~ - 1)

DAT

entry
         mov       command,par             ' Could use "par" but easier to read code
         mov       paramError,command      ' Point to ...
         add       paramError,#4           ' ... param/error pointer
         mov       bufPtr,paramError       ' Point to ...
         add       bufPtr,#4               ' ... buffer pointer

         rdlong    tmp,paramError          ' Get the I/O pins
         
         mov       curSize,tmp             ' Use bottom byte ...
         and       curSize,#255            ' ... to pick ...
         shl       inputMask,curSize       ' ... input pin mask

         mov       curSize,tmp             ' Use second byte ...
         shr       curSize,#8              ' ... to pick ...
         and       curSize,#255            ' ... output ...
         shl       outputMask,curSize      ' ...  pin mask
         add       CTR_VAL,curSize         ' Add pin number to the counter control value

         mov       curSize,tmp             ' Use third byte ...
         shr       curSize,#16             ' ... to pick ...
         and       curSize,#255            ' ... notice-led mask
         cmp       curSize,#31 wz          ' Value of 31 means ...
  if_z   mov       noticeMask,#0           ' ... no LED
         shl       noticeMask,curSize      ' Pin mask for notice LED   

         mov       tmp,#0                  ' Make sure ...
         mov       outa,tmp                ' ... LED is off
         mov       tmp,outputMask          ' Set output ...
         or        tmp,noticeMask          ' ... pins as outputs.
         mov       dira,tmp                ' All others input

         mov       ctra,tmp
         mov       frqa,FRQ_VAL            ' ... 38KHz clock

         mov       tmp,#0                  ' Ready for ...
         wrlong    tmp,command             ' ... command requests

main     rdlong    tmp,command wz          ' Wait for a ...
   if_z  jmp       #main                   ' ... command             '

         cmp       tmp,#2 wz               ' Is this a playback?
   if_z  jmp       #doPlayback             ' Yes ... do it
         cmp       tmp,#1 wz               ' Is this a record?         
  if_nz  mov       tmp,#99                 ' Error code "Invalid command"
  if_nz  jmp       #clearAndDone           ' No ... ignore this command

doRecord
         mov       outa,noticeMask         ' Turn on the notice LED (if any)
         call      #serv_record            ' Call the record service
         mov       outa,#0                 ' Turn off the notice LED (if any) 
         mov       tmp,#0                  ' No error
         
clearAndDone
         wrlong    tmp,paramError          ' Write the return code
         mov       tmp,#0                  ' Signal the ...
         wrlong    tmp,command             ' ... end of processing                              
         jmp       #main                   ' Wait for next decode request

doPlayback
         mov       outa,noticeMask         ' Turn on the notice LED (if any)
         call      #serv_play              ' Call the play routine         
         mov       tmp,#0                  ' No error
         jmp       #clearAndDone           ' Tell user we are done


' Recording service:
'
' [bufPtr] contains the pointer to the buffer to fill. The first word of the buffer
' is the max number of bytes (samples are words). After recording the first word
' contains the number of bytes written to the buffer.                
'
serv_record                           
         rdlong    bufSize,bufPtr          ' This is the buffer to fill (size is 1st word)
         mov       dataPtr,bufSize         ' Next word starts the ...
         add       dataPtr,#2              ' ... buffer to fill

         rdbyte    maxSize,bufSize         ' Read ...
         add       bufSize,#1              ' ... max buffer siz.e ...           
         rdbyte    tmp,bufSize             ' ... This might not ...
         shl       tmp,#8                  ' ... be ... 
         sub       bufSize,#1              ' ... word ...
         add       maxSize,tmp             ' ... aligned (no rdword)

         mov       curSize,#0              ' Current number of bytes stored 
        
waitFirst        
         and       inputMask,ina wz,nr     ' Wait for the first low value ...             
  if_nz  jmp       #waitFirst              ' ... at start of transmission                  

         mov       tmp,cnt                 ' Calculate the first ...
         add       tmp,resol               ' ... resoultion interval
         
         mov       pulseCnt,#1             ' Init pulse count (we always wait 1)
         mov       curpul,leadpul          ' The leader-pulse can be very long
         
goHigh   waitcnt   tmp,resol               ' Wait until the next resolution interval
         and       inputMask,ina wz, nr    ' Wait for the input pin ...
  if_nz  jmp       #wentHigh               ' ... to go high 
         add       pulseCnt,#1             ' Still low ... count this interval
         cmp       pulseCnt,curpul wz,wc   ' Max pulse width reached (this would be an error)?
  if_ae  jmp       #done                   ' Yes ... done        
         jmp       #goHigh                 ' Keep waiting for a high

wentHigh mov       tmp2,pulseCnt           ' Write ...
         shr       tmp2,#8                 ' ... two-byte ...
         wrbyte    pulseCnt,dataPtr        ' ... sample ...
         add       dataPtr,#1              ' ... that might not be
         wrbyte    tmp2,dataPtr            ' ... word aligned ...
         add       dataPtr,#1              ' ... (no wrword)
         
         add       curSize,#2              ' Count the number of bytes
         cmp       curSize,maxSize wz,wc   ' Reached the given end
  if_ae  jmp       #done                   ' Yes ... that's all we can do
         mov       pulseCnt,#1             ' Next pulse count

         mov       curpul,maxpul           ' From now on we timeout on a smaller pulse

goLow    waitcnt   tmp,resol               ' Wait until the next resolution interval    
         and       inputMask,ina wz, nr    ' Wait for the input pin ...
  if_z   jmp       #wentLow                ' ... to go low
         add       pulseCnt,#1             ' Still high ... count this interval
         cmp       pulseCnt,curpul wz,wc   ' Max pulse width reached (end of transmission)?
  if_ae  jmp       #done                   ' Yes ... done                                        
         jmp       #goLow                  ' Keep waiting for low
         
wentLow  mov       tmp2,pulseCnt           ' Write ...
         shr       tmp2,#8                 ' ... two-byte ...
         wrbyte    pulseCnt,dataPtr        ' ... sample ...
         add       dataPtr,#1              ' ... that might not be
         wrbyte    tmp2,dataPtr            ' ... word aligned ...
         add       dataPtr,#1              ' ... (no wrword)
         
         add       curSize,#2              ' Count the number of entries
         cmp       curSize,maxSize wz,wc   ' Reached the given end
  if_ae  jmp       #done                   ' Yes ... that's all we can do
         mov       pulseCnt,#1             ' Next pulse count            
         
         jmp       #goHigh                 ' Wait for the next high transition   

done     mov       tmp,curSize             ' Store number ...
         shr       tmp,#8                  ' ... of samples ...
         wrbyte    curSize,bufSize         ' ... might not ...
         add       bufSize,#1              ' ... be word aligned ...
         wrbyte    tmp,bufSize             ' ... (no wrword)

serv_record_ret
         ret 
                                                                  


' [bufPtr] contains the pointer to the buffer to play out. The first word of the buffer
' is the number of bytes (samples are words) in the buffer.
'
serv_play

         ' We assume the IR-LED is wired so that a 1 turns it ON and
         ' a 0 turns it OFF.
         
         ' Setting output to 0 allows the clock to control (38KHz)
         ' Setting output to 1 forces the output to always 1 (LED off)

         rdlong    bufSize,bufPtr          ' This is the buffer to play (size is 1st word)
         mov       dataPtr,bufSize         ' Next word starts the ...
         add       dataPtr,#2              ' ... buffer to play

         rdbyte    maxSize,bufSize         ' Read ...
         add       bufSize,#1              ' ... two-byte ...             
         rdbyte    tmp,bufSize             ' ... This might not ...
         shl       tmp,#8                  ' ... buffer size. ... 
         sub       bufSize,#1              ' ... be word ...
         add       maxSize,tmp             ' ... aligned (no rdword)
                
         mov       curSize,#0              ' Current number of bytes played out                                                                                

         mov       tmp,cnt                 ' Calculate the first ...
         add       tmp,resol               ' ... resoultion interval
         
         mov       tmp2,#0                 ' Start the pulses with an ON (1)

playLoop  
         xor       tmp2,#1 wz              ' Change pulse polarity
  if_z   mov       ctra,tmp2               ' 0=off
  if_nz  mov       ctra,CTR_VAL            ' 1=38Hz  

         cmp       curSize,maxSize wz,wc   ' Start of interval. Have we done them all?
  if_ae  jmp       #doPlaybackDone         ' Yes ... out


         rdbyte    pulseCnt,dataPtr        ' Read ...
         add       dataPtr,#1              ' ... two-byte ...        
         rdbyte    tmp3,dataPtr            ' ... This might not ...
         shl       tmp3,#8                 ' ... sample. ...
         add       dataPtr,#1              ' ... be word ...
         add       pulseCnt,tmp3           ' ... aligned (no rdword)
                
         add       curSize,#2                         

pulseLoop                         
         waitcnt   tmp,resol               ' Wait the timing interval
         sub       pulseCnt,#1 wz,wc       ' All done?
  if_nz  jmp       #pulseLoop              ' No ... keep counting

         jmp       #playLoop               ' Next pulse    
 
doPlaybackDone

         mov       tmp2,#0
         mov       outa,tmp2              ' Set output to 0 (LED off)

serv_play_ret
         ret                      

command    long   0              ' Pointer to command
paramError long   0              ' Pointer to command/error
bufPtr     long   0              ' Pointer to buffer pointer

bufSize    long   0              ' Pointer to sample buffer size
dataPtr    long   0              ' Current sample data cursor
maxSize    long   0              ' Max size of sample input buffer
curSize    long   0              ' Current size of sample input buffer

inputMask  long   1              ' Pin number (shifted at start)
outputMask long   1              ' Pin number (shifted at start)
noticeMask long   1              ' Pin number (shifted at start)

tmp        long   0              ' Misc use
tmp2       long   0              ' Misc use
tmp3       long   0              ' Misc use

pulseCnt   long   0              ' Current pulse count            

curpul     long   0              ' Current max-pulse wait time 
leadpul    long   $F0000000      ' Max pulse count for lead in (can be long)             
maxpul     long   maxPulse       ' Max pulse count ... considered timeout

resol      long   resolution     ' Offset for WAITCNT in the pulse counting

CTR_VAL    long  %00100_000 << 23 + 1 << 9 +  0  ' This 0 gets changed to pin number at startup 
FRQ_VAL    long  $1f_2000

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
                                                                          