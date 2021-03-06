'' **************************************
'' *  PhaseMod GeneralMIDI-Synthesizer  *  version 1.0
'' **************************************
'' (c)2009 Andy Schenk, www.insonix.ch/propeller ( see MIT license at end)
''
'' Multitimbral Synthesizer with GM1 soundset, and GM1 drum set on channel 10.
'' Generates 10 voices in 1 cog, or 20 voices in 2 cogs. 
''
'' Voice architecture:                                        Parameters: (10 bytes)
''                           ┌─────┐                          - volume              0..255
'' ┌──────┐  ┌───┐           │ Env │                          - panorama            0..127
'' │ Osc2 ├──┤├─┬────┐    └──┬──┘      pl                  - semitone osc1       0..255
'' └──────┘  └───┘ │        ┌──┴──┐    ┌── L DAC          - semitone osc2       0..255
''         pm┌──├─┘   (+)──┤ DCA ├─┬──┤                     - detune osc2         0..255
'' ┌──────┐    ┌───┐       └─────┘ │  └── R DAC          - PhaseMod intensity  7..0
'' │ Osc1 ├(+)─┤├───┴─┐pm      │    pr                  - Feedback intensity  7..0
'' └──────┘    └───┘               │                        - Envelope Attack     0..255
''           └─────├─────(+)──────┘                        - Envelope Decay&Release  0..255
''                 fb                                         - Envelope Sustain    0..255
''
''Legend:  = SawtoothTriangle Shaper, (+) = Mixer,  ├ = 2^n Attenuator (shifts)
'' Osc = Sawtooth Oscillator  (DDS)
'' Env = Envelope Generator (A D/R S)
'' DCA = Digital Attenuator (mult 8*32)
''

 #0, volp, pan, semi1, semi2, detune, pmi, fbi, eat, edy, esu   'synth parameter index enumeration

''Sound parameter tipps:
'' PM and FB are 2^n Attenuators, realized with a simple right shift (SAR instruction)
'' that is: 0 is no attenuation and 1 is 1/2 value 2=1/4 value and so on. values over 7
'' have no noticable effect.
'' if you set FB to 0 and PM to 0..2 you get noise sounds, because of the havy feedback.
''
'' One part of feedback modulation comes from the envelope modulated output, and the sound
'' is therefore not only volume modulated, but also the timbre changes with the envelope.
''
'' if you set semi1 or semi2 to 128..255 you get a low frequency from this oscillator. Combined
'' with feedback, noise sounds with no tonal parts are possible.
''
'' PM (phase modulation) synthesis works the same as FM for higher frequencies. On FM synthesizers, the
'' Oscillators produce sine waves, but this synth works with triangle waves. The sound generation
'' principals are the same: No PM or FB produces low harmonics, with PM or FM the harmonics
'' relate on the frequency ratio of the oscillators. With both osc at the same freq. the sound
'' is sawtooth like, with osc2=2*osc1 the sound is more square wave like. With odd ratios, you
'' get a lot of disharmonic sounds, like bells. 
'' You can set the frequency of the oscillators only in semitones, to get exact ratios this table can help:
'' 1*freq = 0, 2*freq=12, 4*freq=24 (3*freq≈19, 5*freq≈28)     

VAR
 long fqtab[128]                                        'Frequency values for notes
 long i, k
 long cog1, cog2, nVc, mVc
 
 long auxL, auxR, cmd2, cmnd                            'Assembly parameters
 long cmlp, cmrp, pinlr, rticks                         '(8 contiguous longs)
 
 long rte, inc1, inc2, env, mods                        'for voice parameter passing
 long rotvc                                             'for rotating voice allocation
 word vcstate[20]                                       'voice status
 byte vol[16], prog[16], panc[16]                       'channel values


PUB start(Lpin,Rpin,Cogs) : okay | v         ''start Synth, starts 1..2 cogs
'' Lpin, Rpin = Audio Out Pins (for mono: Rpin = -1)
  nVc := 20                                  '' Cogs = 2: 20 voices in 2 cogs
  if Cogs == 1
    nVc := 10                                '' Cogs = 1: 10 voices in 1 cog
  mVc := nVc-1
  
  repeat k from 9 to 0                       'generate Freq Table
    repeat  i from 0 to 11
      v := constant(1<<30 / 16000)  * word[i<<1+@octav]
      fqtab[k*12+i] := v >> (9-k)

  repeat i from 0 to 15                      'controller defaults
    vol[i] := 127
    prog[i] := 0
    panc[i] := 64

  rticks := clkfreq/32000                    'sample freq = 32kHz
  cmlp := %00110<<26 + Lpin                  'set DUTY counter mode for DACs
  pinlr := 1<<Lpin
  cmrp := 0
  if Rpin => 0                               'stereo?
    cmrp := %00110<<26 + Rpin
    pinlr |= (1<<Rpin)
  cog1 := cognew(@entry, @auxL)+1            'start 1.cog synth
  if cog1 and Cogs>1
    waitcnt(8192+cnt)
    byte[@entry+4] := 8                      'modify assembly code for 2.cog
    cog2 := okay := cognew(@entry, @auxL)+1  'start 2.cog synth
  allOff
  if okay
    okay := @pres                            '' return pointer to sound parameters if OK


PUB stop                                     ''stop synth - frees up to 2 cogs
  if cog1
    byte[@entry+4] := 12
    cogstop(cog1~ -1)
  if cog2
    cogstop(cog2~ -1)


PUB noteOn(key,chan,vel) | dy,pb1,v          ''start a note
  v := chan<<8 + key
  repeat i from 0 to mVc                     'search free voice
    rotvc := (rotvc + 1) // nVc
    if vcstate[rotvc]==0 or vcstate[rotvc]==v
      quit
  if chan == 9
    if key<35 or key>81
      return
    v := (key-35)*10 + @drset                'Drum Set or..
  else
    v := prog[chan]*10 + @pres               '..Instruments

  i := byte[v+semi1]                         'Pitch 1
  if i<128 
    inc1 := fqtab[i+key]                     'according note
  else
    inc1 := (i-128) << 14                    'low frequ if semi > 127

  i := byte[v+semi2]                         'Pitch 2
  if i<128 
    inc2 := byte[v+detune]<<14               'according note with detune
    inc2 += fqtab[i+key]
  else
    inc2 := (i-128) << 14                    'low frequ if semi > 127
    
  i := panc[chan]>>4<<1                      'Panorama 
  k := byte[@pantab+i]
  i := byte[@pantab+i+1]
  mods := i<<24 + k<<16 + byte[v+fbi]<<8 + byte[v+pmi]   'modulation values
  env := 0
  dy := byte[v+volp]                         'Volume
  if key>70
    dy := dy*(70+128-key) / 128              'Key scaling
  dy := vol[chan]*vel*dy / 58000             'Velocity
  rte := byte[v+eat]<<24 + byte[v+edy]<<16 + byte[v+esu]<<8 + dy   'Env rates
  k :=  @rte<<12 + 4<<9 + ((rotvc//10)*11)
  if rotvc < 10                                       
    repeat until cmnd==0                     'pass to assembly cog 1 or
    cmnd := k
  else
    repeat until cmd2==0                     'to assembly cog 2
    cmd2 := k

  vcstate[rotvc] := chan<<8+key              'set voice state


PUB noteOff(key,chan)  | st, v               ''release a note 
  st := chan<<8+key
  repeat i from 0 to mVc                     'search key and channel in voices
    if vcstate[i] == st
      v := prog[chan]*10 + @pres             'set to release if found
      k := (i//10)*11 + 3
      if i < 10
        repeat until cmnd==0                 'in cog1
        cmnd := k
      else
        repeat until cmd2==0                 'in cog2
        cmd2 := k
      vcstate[i] := 0


PUB prgChange(num,chan)                      ''Program Change
  prog[chan] := num
  if chan==9
    panc[chan] := byte[num*10 + @drset + pan]
  else
    panc[chan] := byte[num*10 + @pres + pan]


PUB volContr(vo,chan)                        ''Volume Controller
  vol[chan] := vo

PUB panContr(pa,chan)                        ''Panorama Controller
  panc[chan] := pa


PUB allOff  | kn,v                          ''all Notes off
  repeat v from 0 to 9
    kn := v*11 + 3
    repeat until cmnd==0
    cmnd := kn
    cmd2 := kn
    vcstate[v] := 0
    vcstate[v+10] := 0


DAT
octav word 4186,4435,4699,4978,5274,5588,5920,6272,6645,7040,7459,7902

' Instrument parameters for GM1 sound set   (don't expect to much correspondence with sound name :-)
'         vol pan s1 s2 dt pm fb at dr su
pres
  byte 200,64, 12,0,7, 13,2, 255,19,38  '1 Grand Piano
  byte 200,64, 0,0,7, 13,2, 255,19,38   '2 Bright Piano
  byte 200,64, 0,12,7, 13,2, 255,19,38  '3 Electric Piano
  byte 200,64, 12,0,16, 4,1, 255,57,25  '4 Honkytonk
  byte 200,64, 12,0,09, 4,2, 255,33,40  '6 E-Piano 1
  byte 200,64, 0,12,17, 1,6, 255,39,22  '5 E-Piano 2
  byte 200,64, 12,0,6, 4,1, 255,57,25   '7 Hapsichord
  byte 200,64, 0,12,17, 1,5, 255,39,22  '8 Clavi

  byte 200,32, 12,12,3, 1,7, 255,37,0   '9  Celesta
  byte 200,32, 12,17,3, 1,7, 255,37,0   '10 Glockenspiel
  byte 200,32, 12,24,13, 1,7, 255,37,0  '11 MusicBox
  byte 200,32, 24,0,13, 5,3, 255,37,0   '12 Vibraphone
  byte 200,32, 0,12,13, 1,5, 255,57,0   '13 Marimba
  byte 200,32, 24,0,13, 5,3, 255,57,0   '14 Xylophon
  byte 200,32, 24,7,13, 3,3, 255,12,0   '15 Tubular Bells
  byte 200,32, 12,3,3, 1,7, 255,37,0    '16 Dulcimer

  byte 120,64, 0,24,19, 3,3, 18,79,113  '17 Organ
  byte 120,64, 0,12,19, 5,2, 200,49,80  '18 Perc Organ
  byte 100,64, 12,0,19, 3,2, 18,59,85   '19 Rock Organ 
  byte 150,64, 0,24,19, 3,5, 28,69,113  '20 Church Organ
  byte 120,64, 12,0,19, 5,2, 18,69,113  '21 Reed Organ
  byte 150,64, 12,0,19, 5,2, 18,69,113  '22 Accordion 
  byte 150,64, 0,12,19, 5,2, 18,69,99   '23 Harmonica
  byte 150,64, 0,12,19, 7,1, 18,69,129  '24 Tango Accordion

  byte 200,64, 24,12,6, 4,3, 255,47,25  '25 Guitar
  byte 200,64, 24,12,6, 4,1, 255,47,25  '26 Steel Guitar
  byte 200,64, 12,24,16, 2,3, 255,37,25 '27 Jazz Guitar
  byte 200,64, 24,12,6, 4,1, 255,37,25  '28 E-Guitar
  byte 200,64, 24,12,6, 4,2, 255,67,25  '29 E-Guitar muted
  byte 200,64, 24,12,6, 2,1, 255,47,89  '30 OverdriveGuitar
  byte 200,64, 24,12,6, 1,3, 199,57,125 '31 DistortionGuitar
  byte 140,64, 12,24,6, 1,4, 255,57,25  '32 Guitar harmonics

  byte 250,64, 12,12,07, 3,2, 255,47,40  '33 Acoustic Bass
  byte 250,64, 24,12,07, 4,2, 255,47,40  '34 Electric Bass
  byte 250,64, 24,12,07, 5,1, 255,67,0   '35 Pick Bass
  byte 250,64, 12,12,07, 5,1, 255,67,0   '36 Fretless Bass
  byte 250,64, 12,12,0, 2,1, 255,57,10   '37 Slap Bass1
  byte 250,64, 12,12,0, 3,1, 255,57,10   '38 Slap Bass2
  byte 250,64, 12,12,07, 3,1, 255,47,40  '39 Synth Bass1
  byte 250,64, 24,12,0, 3,1, 255,47,10   '40 Synth Bass2

  byte 120,64, 12,0,0, 6,2, 9,29,180    '41 Violine
  byte 120,64, 12,0,3, 6,2, 12,33,180   '42 Viola
  byte 120,64, 0,12,5, 1,4, 7,27,170    '43 Cello
  byte 120,64, 12,12,0, 3,2, 7,27,170   '44 Contrabass
  byte 150,64, 12,0,9, 2,4, 9,29,130    '45 TremoloStrings
  byte 200,64, 12,0,0, 3,5, 255,70,0    '46 Pizzicato
  byte 200,64, 12,0,0, 3,5, 255,50,10   '47 Harp
  byte 200,40, 0,12,42, 5,0, 255,57,0   '48 Timpani

  byte 150,64, 12,0,9, 1,4, 9,29,130    '49 String Ensemble1
  byte 100,64, 12,12,11, 1,4, 15,19,190 '50 String Ensemble2
  byte 120,64, 12,0,9, 2,4, 9,25,130    '51 Synth Strings1
  byte 120,64, 0,12,9, 1,4, 9,29,130    '52 Synth Strings2
  byte 150,64, 12,0,9, 2,5, 12,29,180   '53 Ahh
  byte 150,64, 12,0,9, 6,2, 12,29,180   '54 Ohh
  byte 150,64, 12,0,9, 6,1, 12,39,150   '55 Synth Voice
  byte 250,64, 12,0,19, 6,2, 50,29,70   '56 Orchester Hit

  byte 200,64, 12,24,19, 3,1, 15,89,98  '57 Trumpet
  byte 200,64, 12,24,19, 3,1, 15,89,78  '58 Trombone
  byte 200,64, 0,0,0, 2,1, 15,89,98     '59 Tuba
  byte 200,64, 24,12,0, 4,1, 15,99,92   '60 muted Trumpet
  byte 200,96, 0,24,19, 3,1, 18,139,118 '61 French Horn
  byte 200,64, 0,12,23, 4,1, 20,89,118  '62 Brass section
  byte 200,64, 24,12,13, 4,1, 20,89,121 '63 Synth Brass 1
  byte 200,64, 12,12,13, 4,1, 15,89,138 '64 Synth Brass 2

  byte 200,64, 0,0,0, 2,1, 15,89,98     '65 Soprano Sax
  byte 200,64, 12,0,0, 2,1, 15,89,113   '66 Alto Sax
  byte 200,64, 0,12,0, 2,1, 15,89,103   '67 Tenor Sax
  byte 200,64, 0,0,0, 1,2, 15,89,153    '68 Bariton Sax
  byte 200,96, 0,24,19, 3,1, 18,139,88  '69 Oboe
  byte 200,96, 0,24,2, 2,1, 18,79,118   '70 English Horn
  byte 200,96, 0,12,2, 3,1, 18,79,118   '71 Bassoon
  byte 200,96, 12,0,5, 1,4, 18,139,198  '72 Clarinet

  byte 200,96, 0,0,0, 5,5, 58,139,128   '73 Piccolo
  byte 200,16, 0,0,0, 5,4, 38,139,188   '74 Flute
  byte 200,96, 0,0,0, 5,5, 58,139,128   '75 Recorder
  byte 250,96, 12,0,0, 4,0, 18,139,78   '76 PanFlute
  byte 250,96, 12,0,0, 4,0, 18,139,78   '77 BlownBottle
  byte 200,96, 12,0,3, 2,0, 18,139,68   '78 Shakuhachi
  byte 150,96, 128,12,0, 1,0, 13,139,55 '79 Whistle
  byte 200,96, 12,0,3, 0,4, 44,139,55   '80 Ocarina

  byte 160,64, 0,12,9, 4,1, 75,89,78    '81 SquareSynth
  byte 180,64, 0,0,9, 5,1, 75,89,98     '82 SawSynth
  byte 170,96, 0,12,27, 1,1, 19,139,103 '83 Calliope
  byte 150,64, 0,12,9, 3,1, 75,89,118   '84 Chiff
  byte 150,64, 0,12,9, 3,0, 75,89,90    '85 Charang
  byte 130,64, 12,0,9, 6,2, 12,29,180   '86 Voice
  byte 150,64, 0,5,0, 4,3, 23,19,130    '87 Fifth
  byte 150,64, 12,0,7, 3,1, 255,47,90   '88 Bass&Lead

  byte 100,64, 0,12,9, 5,1, 9,19,130    '89 Synth Pad
  byte 100,64, 0,12,9, 6,2, 9,19,130    '90 warm Pad
  byte 100,64, 12,0,9, 1,4, 19,19,120   '91 PolySynth Pad
  byte 100,64, 12,0,9, 2,5, 12,29,180   '92 Choir Pad
  byte 100,64, 12,0,9, 1,4, 9,19,130    '93 bowed Pad
  byte 130,64, 0,24,9, 1,4, 9,19,90     '94 metal Pad
  byte 100,64, 12,0,9, 1,4, 9,19,130    '95 halo Pad
  byte 130,64, 0,12,9, 5,1, 255,129,78  '96 sweep

  byte 200,64, 128,219,77, 1,0, 1,11,90 '97 Rain
  byte 200,32, 12,17,3, 1,7, 255,37,0   '98 Soundtrack
  byte 150,64, 12,0,9, 1,4, 9,19,130    '99 crystal
  byte 150,64, 12,0,6, 4,3, 255,39,130  '100 Atmosphere
  byte 150,64, 0,0,9, 4,4, 2,19,130     '101 Brightness
  byte 150,64, 12,0,9, 5,3, 2,19,130    '102 Goblins
  byte 200,64, 12,0,22, 1,2, 255,19,30  '103 Echoes
  byte 200,64, 12,134,22, 1,2, 255,19,30 '104 SciFi

  byte 200,64, 0,132,22, 0,2, 255,23,10 '105 Sitar
  byte 250,64, 12,0,16, 3,1, 255,47,20  '106 Banjo
  byte 150,64, 12,0,16, 2,2, 255,47,60  '107 Shamisen
  byte 250,64, 12,0,12, 5,0, 255,77,30  '108 Koto
  byte 250,64, 0,12,12, 3,0, 255,166,10 '109 Kalimba
  byte 150,96, 0,12,5, 2,1, 18,79,168   '110 BagPipe  
  byte 150,64, 12,0,3, 6,1, 19,49,180   '111 Fiddle
  byte 200,32, 0,19,13, 1,5, 255,57,0   '112 Shanai

  byte 220,64, 0,17,42, 3,1, 255,77,0   '113 Tinkle Bell
  byte 200,32, 19,0,53, 5,3, 255,37,0   '114 Agogo Bell
  byte 250,32, 17,0,53, 4,3, 255,37,20  '115 Steel Drum
  byte 200,32, 25,0,53, 4,3, 255,137,0  '116 Wood Blocks
  byte 250,32, 19,0,53, 5,3, 255,37,0   '117 Taiko Drum
  byte 200,64, 128,0,0, 1,1, 255,47,0   '118 melodic Tom
  byte 200,32, 0,0,0, 7,0, 255,47,0     '119 Synth Drum
  byte 150,64, 128,128,0, 3,0, 1,221,0  '120 Reverse Cymbal

  byte 160,64, 128,128,0, 2,1, 9,221,0  '121 Guitar Noise
  byte 160,64, 128,128,0, 1,1, 12,55,0  '122 Breath Noise
  byte 200,64, 128,128,0, 0,1, 2,15,60  '123 Seashore
  byte 200,64, 12,193,0, 2,6, 19,15,60  '124 Bird Tweet
  byte 200,64, 12,193,0, 0,7, 19,15,60  '125 Telephone
  byte 200,64, 128,189,0, 0,1, 2,15,170 '126 Helicopter
  byte 100,64, 128,149,0, 0,0, 2,15,170 '127 Applause
  byte 200,64, 128,144,0, 0,0, 255,19,0 '128 Gunshot

' Drum Set
drset
  byte 250,64, 20,128,0, 3,1, 255,137,40 '35 Bass Drum 2
  byte 250,64, 20,128,0, 3,1, 255,137,40 '36 Bass Drum 1
  byte 200,16, 50,10,115, 5,1,255,167,0  '37 SideStick
  byte 200,64, 24,0,0, 2,0, 255,87,10    '38 SnareDrum 1
  byte 200,96, 180,40,0, 0,1, 255,97,0   '39 Hand Clap
  byte 200,64, 18,0,0, 2,0, 255,87,10    '40 SnareDrum 2
  byte 200,24, 128,12,0, 1,1, 255,67,0   '41 Low Tom 2
  byte 200,16, 128,128,0, 3,0, 255,77,0  '42 Closed HH
  byte 200,24, 128,12,0, 1,1, 255,67,0   '43 Low Tom 1
  byte 200,64, 128,128,0, 2,0, 255,31,0  '44 Pedal HH
  byte 200,64, 128,15,0, 1,1, 255,67,0   '45 Mid Tom 2
  byte 200,64, 128,128,0, 3,0, 255,31,0  '46 Open HH
  byte 200,64, 128,13,0, 1,1, 255,67,0   '47 Mid Tom 1
  byte 200,80, 128,20,0, 1,1, 255,67,0   '48 High Tom 2
  byte 200,64, 128,177,0, 2,0, 255,21,0  '49 Crash Cymbal
  byte 200,80, 128,18,0, 1,1, 255,67,0   '50 High Tom 1
  byte 150,64, 128,80,0, 0,1, 255,33,0   '51 Ride Cymbal
  byte 200,64, 128,199,0, 0,1, 255,23,0  '52 Chinese Cymb
  byte 200,64, 128,83,0, 0,1, 255,43,0   '53 Ride Bell
  byte 200,80, 20,128,0, 4,0, 197,77,0   '54 Tambourine
  byte 200,96, 128,212,0, 1,0, 255,33,0  '55 Splash Cymbal
  byte 100,112,21,36,13, 5,2, 255,77,0   '56 Cowbell
  byte 200,96, 128,212,0, 1,0, 255,25,0  '57 Crash Cymbal 2
  byte 200,112,210,16,0, 2,2, 255,37,0   '58 Vibra Slap
  byte 200,96, 128,212,0, 0,1, 255,33,0  '59 Ride Cymbal 2
  byte 200,40, 20,13,33, 5,2,255,87,0    '60 High Bongo
  byte 200,70, 7,0,33, 5,2, 255,87,0     '61 Low Bongo
  byte 200,36, 22,15,33, 5,2, 255,57,0   '62 High Conga
  byte 200,32, 21,14,33, 5,2, 255,37,0   '63 Open Hi Conga 
  byte 200,32, 17,10,33, 5,2, 255,57,0   '64 Open Conga 
  byte 200,96, 14,7,33, 7,1, 255,57,0    '65 High Timbal
  byte 200,80, 9,2,33, 7,1, 255,57,0     '66 Low Timbal
  byte 200,16, 31,12,53, 5,3, 255,47,0   '67 High Agogo
  byte 200,24, 23,4,53, 5,3, 255,37,0    '68 Low Agogo
  byte 200,80, 128,177,0, 3,0, 4,221,0   '69 Cabasa
  byte 200,80, 129,211,0, 2,0, 4,51,0    '70 Maracas
  byte 200,96, 128,25,0, 1,0, 13,139,0   '71 Short Whistle
  byte 200,96, 128,24,0, 1,0, 13,59,0    '72 Long Whistle
  byte 200,48, 129,211,0, 0,1, 4,91,0    '73 Short Guiro
  byte 200,48, 129,211,0, 0,1, 4,51,0    '74 Long Guiro
  byte 200,16, 129,128,0, 0,1, 8,51,0    '75 Claves
  byte 200,32, 25,1,53, 4,3, 255,137,0   '76 High Wood
  byte 200,32, 13,0,53, 4,3, 255,137,0   '77 Low Wood
  byte 200,96, 129,211,0, 0,1, 4,91,0    '78 Mute Cuica
  byte 200,96, 129,211,0, 0,1, 4,61,0    '79 Open Cuica
  byte 120,32, 59,39,43, 1,3, 255,127,0  '80 Mute Triangle
  byte 120,32, 58,38,43, 1,3, 255,87,0   '81 Open Triangle

  byte 100,96, 128,212,0, 0,1, 255,123,0 '82.. Short Ride for higher notes

pantab
      byte 1,4, 1,3, 1,2, 1,1, 1,1, 2,1, 3,1, 4,1      '8 panorama steps (right-shifts)
'      byte 2,5, 2,4, 2,3, 2,2, 2,2, 3,2, 4,2, 5,2      '1/2 volume
'      byte 3,6, 3,5, 3,4, 3,3, 3,3, 4,3, 5,3, 6,3      '1/4 volume

DAT
'---- Assembly PhasModulation Synthesis ----
' the same code is used for both cogs, with 1 modification for the command register
' All voices are unrolled and registers are direct addressed to be as fast as possible

            org  0
entry       mov  cp,par
modify      add  cp,#12             'cog2: #8
            mov  pp,par
            mov  auxp1,pp
            mov  auxp2,pp
            add  auxp2,#4
            add  pp,#16
            
            test modify,#4   wz
     if_nz  rdlong ctra,pp          'init Pins, counters and rate (cog1)
            add  pp,#4
     if_nz  rdlong ctrb,pp
            add  pp,#4
     if_nz  rdlong dira,pp
            add  pp,#4
            rdlong rate,pp          'rate also for cog2
            sub  pp,#16
            mov  tm,cnt
            add  tm,rate

loop        rdlong cmd,cp     wz    'Audio Loop
     if_nz  call #copypar
     if_z   call #envsub
            mov  mixl,#0
            mov  mixr,#0
            call #voices            'calc 10 voices
            cmp  cp,pp        wz    'cog1 or 2 ?
     if_nz  jmp  #cogn2
            rdlong t1,auxp1         'cog1: add aux
            add  mixl,t1
            maxs mixl,maxout        'limiter
            rdlong t2,auxp2
            add  mixr,t2
            mins mixl,minout
            maxs mixr,maxout
            mins mixr,minout
            shl  mixl,#1
            shl  mixr,#1
            add  mixl,bit31         'to DAC
            add  mixr,bit31
            mov  frqa,mixl
            mov  frqb,mixr
loopend     waitcnt tm,rate         '32kHz periode
            jmp  #loop

cogn2       wrlong mixl,auxp1       'cog2: write output to aux
            wrlong mixr,auxp2
            jmp  #loopend

voices      add  phs02,inc02        'Osc 2   voice 0
            abs  t2,phs02
            add  phs01,inc01        'Osc 1
            sar  t2,pm0
            mov  t1,phs01
            add  t1,t2              'PM
            mov  t2,fbrg0
            sar  t2,fb0             'FB
            add  t1,t2
            add  t1,t2
            abs  t1,t1              'Mixer
            mov  fbrg0,t1
            sar  fbrg0,pm0
            sub  t1,middle
            addabs  t1,phs02
            mov  fakt,env0           'DCA
            call #mul8
            add  fbrg0,t1           'FB register
            mov  t2,t1
            sar  t1,pl0
            add  mixl,t1
            sar  t2,pr0
            add  mixr,t2            '/44*4 cycles 24 instr

            add  phs12,inc12        'voice 1
            abs  t2,phs12
            add  phs11,inc11
            sar  t2,pm1
            mov  t1,phs11
            add  t1,t2
            mov  t2,fbrg1
            sar  t2,fb1
            add  t1,t2
            add  t1,t2
            abs  t1,t1
            mov  fbrg1,t1
            sar  fbrg1,pm1
            sub  t1,middle
            addabs  t1,phs12
            mov  fakt,env1
            call #mul8
            add  fbrg1,t1
            mov  t2,t1
            sar  t1,pl1
            add  mixl,t1
            sar  t2,pr1
            add  mixr,t2

            add  phs22,inc22        'voice 2
            abs  t2,phs22
            add  phs21,inc21
            sar  t2,pm2
            mov  t1,phs21
            add  t1,t2
            mov  t2,fbrg2
            sar  t2,fb2
            add  t1,t2
            add  t1,t2
            abs  t1,t1
            mov  fbrg2,t1
            sar  fbrg2,pm2
            sub  t1,middle
            addabs  t1,phs22
            mov  fakt,env2
            call #mul8
            add  fbrg2,t1
            mov  t2,t1
            sar  t1,pl2
            add  mixl,t1
            sar  t2,pr2
            add  mixr,t2

            add  phs32,inc32        'voice 3
            abs  t2,phs32
            add  phs31,inc31
            sar  t2,pm3
            mov  t1,phs31
            add  t1,t2
            mov  t2,fbrg3
            sar  t2,fb3
            add  t1,t2
            add  t1,t2
            abs  t1,t1
            mov  fbrg3,t1
            sar  fbrg3,pm3
            sub  t1,middle
            addabs  t1,phs32
            mov  fakt,env3
            call #mul8
            add  fbrg3,t1
            mov  t2,t1
            sar  t1,pl3
            add  mixl,t1
            sar  t2,pr3
            add  mixr,t2

            add  phs42,inc42        'voice 4
            abs  t2,phs42
            add  phs41,inc41
            sar  t2,pm4
            mov  t1,phs41
            add  t1,t2
            mov  t2,fbrg4
            sar  t2,fb4
            add  t1,t2
            add  t1,t2
            abs  t1,t1
            mov  fbrg4,t1
            sar  fbrg4,pm4
            sub  t1,middle
            addabs  t1,phs42
            mov  fakt,env4
            call #mul8
            add  fbrg4,t1
            mov  t2,t1
            sar  t1,pl4
            add  mixl,t1
            sar  t2,pr4
            add  mixr,t2

            add  phs52,inc52        'voice 5
            abs  t2,phs52
            add  phs51,inc51
            sar  t2,pm5
            mov  t1,phs51
            add  t1,t2
            mov  t2,fbrg5
            sar  t2,fb5
            add  t1,t2
            add  t1,t2
            abs  t1,t1
            mov  fbrg5,t1
            sar  fbrg5,pm5
            sub  t1,middle
            addabs  t1,phs52
            mov  fakt,env5
            call #mul8
            add  fbrg5,t1
            mov  t2,t1
            sar  t1,pl5
            add  mixl,t1
            sar  t2,pr5
            add  mixr,t2

            add  phs62,inc62        'voice 6
            abs  t2,phs62
            add  phs61,inc61
            sar  t2,pm6
            mov  t1,phs61
            add  t1,t2
            mov  t2,fbrg6
            sar  t2,fb6
            add  t1,t2
            add  t1,t2
            abs  t1,t1
            mov  fbrg6,t1
            sar  fbrg6,pm6
            sub  t1,middle
            addabs  t1,phs62
            mov  fakt,env6
            call #mul8
            add  fbrg6,t1
            mov  t2,t1
            sar  t1,pl6
            add  mixl,t1
            sar  t2,pr6
            add  mixr,t2

            add  phs72,inc72        'voice 7
            abs  t2,phs72
            add  phs71,inc71
            sar  t2,pm7
            mov  t1,phs71
            add  t1,t2
            mov  t2,fbrg7
            sar  t2,fb7
            add  t1,t2
            add  t1,t2
            abs  t1,t1
            mov  fbrg7,t1
            sar  fbrg7,pm7
            sub  t1,middle
            addabs  t1,phs72
            mov  fakt,env7
            call #mul8
            add  fbrg7,t1
            mov  t2,t1
            sar  t1,pl7
            add  mixl,t1
            sar  t2,pr7
            add  mixr,t2

            add  phs82,inc82        'voice 8
            abs  t2,phs82
            add  phs81,inc81
            sar  t2,pm8
            mov  t1,phs81
            add  t1,t2
            mov  t2,fbrg8
            sar  t2,fb8
            add  t1,t2
            add  t1,t2
            abs  t1,t1
            mov  fbrg8,t1
            sar  fbrg8,pm8
            sub  t1,middle
            addabs  t1,phs82
            mov  fakt,env8
            call #mul8
            add  fbrg8,t1
            mov  t2,t1
            sar  t1,pl8
            add  mixl,t1
            sar  t2,pr8
            add  mixr,t2

            add  phs92,inc92        'voice 9
            abs  t2,phs92
            add  phs91,inc91
            sar  t2,pm9
            mov  t1,phs91
            add  t1,t2
            mov  t2,fbrg9
            sar  t2,fb9
            add  t1,t2
            add  t1,t2
            abs  t1,t1
            mov  fbrg9,t1
            sar  fbrg9,pm9
            sub  t1,middle
            addabs  t1,phs92
            mov  fakt,env9
            call #mul8
            add  fbrg9,t1
            mov  t2,t1
            sar  t1,pl9
            add  mixl,t1
            sar  t2,pr9
            add  mixr,t2
voices_ret  ret

envsub      movs rdenv,eptr         'calc 1 envelope every AudioLoop (=3.2kHz fs)
            movd wrenv,eptr
            sub  eptr,#3
            movs rdrt,eptr
rdenv       mov  envv,0-0           'envval [31..9] flags[8..0]
rdrt        mov  pcnt,0-0           'rates a[31..24] dr[23..16] s[15..8] vol[7..0]
            movs flgs,envv
            mov  t1,pcnt
            test flgs,#$180 wz      'flgs %00=attack
      if_nz jmp  #release
            shr  t1,#24
            shl  t1,#20
            add  envv,t1            'A
            max  envv,maxe  wc
      if_nc or   flgs,#$100
            jmp  #envmul
release     shl  t1,#8
            test flgs,#$80  wz
            mov  t2,t1
            shr  t1,#11             'D/R
            shl  t2,#8              'S
            cmp  envv,expe  wc      'exponential D/R with 2 segments
      if_ae shl  t1,#3
            cmp  envv,t2    wc
 if_nc_or_nz sub  envv,t1
            mins envv,#0
envmul      mov  fakt,pcnt
            mov  t1,envv
            call #mul8
            shr  t1,#24
'            and  t1,#$7F
            and  flgs,#$180
            or   flgs,t1
            movs envv,flgs
wrenv       mov  0-0,envv
            add  eptr,#3+11         'next Env
            cmp  eptr,#env0+110  wc
      if_ae mov  eptr,#env0
envsub_ret  ret                    '/51*4 with call

copypar     add  cmd,#rt0          'copy parameter to cogram
            movd copy,cmd          'cmd[25..9]=@pars cmd[8..0]=#vc*11
            movd shval,cmd
            shr  cmd,#9
            mov  pcnt,cmd
            and  pcnt,#7
            shr  cmd,#3     wz
      if_z  jmp  #noff
            cmp  pcnt,#4    wz
copy        rdlong 0-0,cmd
            add  cmd,#4
            add  copy,d_inc
            djnz pcnt,#copy
      if_nz jmp  #copend
            rdlong t1,cmd          '2mod/2pan shifts
            add  shval,d_offs
            mov  pcnt,#4
shval       mov  0-0,t1            '[31..24]=panR [23..16]=panL [15..8]=fb [7..0]=pm
            add  shval,d_inc
            shr  t1,#8
            djnz pcnt,#shval
copend      wrlong pcnt,cp
copypar_ret ret                     '/71*4 with call

noff        mov  t1,shval           'Note Off (flg1=1) if @pars=0
            shr  t1,#9
            movd clflg,t1
            mov  pcnt,#0
clflg       or   0-0,#$80           'set flag
            jmp  #copend

mul8        and  fakt,#$7F          'only 7 bits here
            movs t1,fakt            'Mult signed t1[31..8] by unsigned fakt[7..0]
            sar  t1,#1     wc       'signed result in t1[31..0]
            mov  fakt,t1
            andn fakt,#$FF
      if_nc sub  t1,fakt
            sar  t1,#1     wc
      if_c  add  t1,fakt
            sar  t1,#1     wc
      if_c  add  t1,fakt
            sar  t1,#1     wc
      if_c  add  t1,fakt
            sar  t1,#1     wc
      if_c  add  t1,fakt
            sar  t1,#1     wc
      if_c  add  t1,fakt
            sar  t1,#1     wc
      if_c  add  t1,fakt
mul8_ret    ret                     '20*4 cycles with call

'constants
bit31       long 1<<31
middle      long $8000_0000
rate        long 80_000 / 32        'sample rate
d_inc       long $200
d_offs      long $200*4
maxe        long $7FFFFFFE
expe        long $1FFF0000
maxout      long $3FFF8000
minout      long $C0001000

' registers
pp          long 0
t1          long 0
t2          long 0
fakt        long 0
flgs        long 0
tm          long 0
pcnt        long 0
mixl        long 0
mixr        long 0
envv        long 0
eptr        long env0
cmd         long 0
cp          long 0
auxp1       long 0
auxp2       long 0

' synth regs
phs01       long 0
phs02       long 0
fbrg0       long 0
rt0         long 0                  'bit[31..24]=a [23..16]=dr [15..8]=s [7..0]=vol
inc01       long 0
inc02       long 0
env0        long 0                  'bit[31..27]=ptr bit[26..8]=phs bit[7..0]=flgs
pm0         long 2                  '[8..0]
fb0         long 5                  '{8..0]
pl0         long 2                  '[8..0] Panorama left
pr0         long 2                  '[8..0] Panorama right

phs11       long 0
phs12       long 0
fbrg1       long 0
rt1         long 0
inc11       long 0
inc12       long 0
env1        long 0
pm1         long 2
fb1         long 5
pl1         long 2
pr1         long 2

phs21       long 0
phs22       long 0
fbrg2       long 0
rt2         long 0
inc21       long 0
inc22       long 0
env2        long 0
pm2         long 2
fb2         long 5
pl2         long 2
pr2         long 2

phs31       long 0
phs32       long 0
fbrg3       long 0
rt3         long 0
inc31       long 0
inc32       long 0
env3        long 0
pm3         long 2
fb3         long 5
pl3         long 2
pr3         long 2

phs41       long 0
phs42       long 0
fbrg4       long 0
rt4         long 0
inc41       long 0
inc42       long 0
env4        long 0
pm4         long 2
fb4         long 5
pl4         long 2
pr4         long 2

phs51       long 0
phs52       long 0
fbrg5       long 0
rt5         long 0
inc51       long 0
inc52       long 0
env5        long 0
pm5         long 2
fb5         long 5
pl5         long 2
pr5         long 2

phs61       long 0
phs62       long 0
fbrg6       long 0
rt6         long 0
inc61       long 0
inc62       long 0
env6        long 0
pm6         long 2
fb6         long 5
pl6         long 2
pr6         long 2

phs71       long 0
phs72       long 0
fbrg7       long 0
rt7         long 0
inc71       long 0
inc72       long 0
env7        long 0
pm7         long 2
fb7         long 5
pl7         long 2
pr7         long 2

phs81       long 0
phs82       long 0
fbrg8       long 0
rt8         long 0
inc81       long 0
inc82       long 0
env8        long 0
pm8         long 2
fb8         long 5
pl8         long 2
pr8         long 2

phs91       long 0
phs92       long 0
fbrg9       long 0
rt9         long 0
inc91       long 0
inc92       long 0
env9        long 0
pm9         long 2
fb9         long 5
pl9         long 2
pr9         long 2
            fit

{{
 ───────────────────────────────────────────────────────────────────────────
                Terms of use: MIT License                                   
 ─────────────────────────────────────────────────────────────────────────── 
   Permission is hereby granted, free of charge, to any person obtaining a  
  copy of this software and associated documentation files (the "Software"),
  to deal in the Software without restriction, including without limitation 
  the rights to use, copy, modify, merge, publish, distribute, sublicense,  
    and/or sell copies of the Software, and to permit persons to whom the   
    Software is furnished to do so, subject to the following conditions:    
                                                                            
   The above copyright notice and this permission notice shall be included  
           in all copies or substantial portions of the Software.           
                                                                            
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER   
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER     
                       DEALINGS IN THE SOFTWARE.                            
 ─────────────────────────────────────────────────────────────────────────── 
}}               