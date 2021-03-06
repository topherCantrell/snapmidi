{{

Modified from:
String Engine                                                                                                               
Author: Kwabena W. Agyeman

Contains NO data so it can be used in multiple cogs without data duplication                                                                                                                                
}}

PUB alphabeticallyBefore(characters, charactersBefore) '' 5 Stack Longs

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Compares two strings to see if one comes alphabetically before the other.                                                │
'' │                                                                                                                          │
'' │ Returns true if yes and false if no.                                                                                     │
'' │                                                                                                                          │
'' │ Characters       - A pointer to a string of characters.                                                                  │
'' │ CharactersBefore - A pointer to a string of characters that comes alphabetically before the other string of characters.  │
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  repeat while(byte[characters] and (byte[characters] == byte[charactersBefore]))
    characters++
    charactersBefore++

  if(byte[characters] > byte[charactersBefore])
    return true

PUB alphabeticallyAfter(characters, charactersAfter) '' 5 Stack Longs

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Compares two strings to see if one comes alphabetically after the other.                                                 │
'' │                                                                                                                          │
'' │ Returns true if yes and false if no.                                                                                     │
'' │                                                                                                                          │
'' │ Characters      - A pointer to a string of characters.                                                                   │
'' │ CharactersAfter - A pointer to a string of characters that comes alphabetically after the other string of characters.    │
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  repeat while(byte[characters] and (byte[characters] == byte[charactersAfter]))
    characters++
    charactersAfter++  

  if(byte[characters] < byte[charactersAfter])
    return true

PUB startsWithCharacter(charactersToSearch, characterToFind) '' 5 Stack Longs

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Checks if the string of characters begins with the specified character.                                                  │
'' │                                                                                                                          │
'' │ Returns true if yes and false if no.                                                                                     │
'' │                                                                                                                          │
'' │ CharactersToSearch - A pointer to the string of characters to search.                                                    │                                                           
'' │ CharacterToFind    - The character to find in the string of characters to search.                                        │                                                                           
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  return (byte[charactersToSearch] == characterToFind)

PUB startsWithCharacters(charactersToSearch, charactersToFind)

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Checks if the string of characters begins with the specified characters.                                                 │
'' │                                                                                                                          │
'' │ Returns true if yes and false if no.                                                                                     │
'' │                                                                                                                          │
'' │ CharactersToSearch - A pointer to the string of characters to search.                                                    │                                                           
'' │ CharactersToFind   - A pointer to the string of characters to find in the string of characters to search.                │                                                                           
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  return (charactersToSearch == findCharacters(charactersToSearch, charactersToFind))

PUB endsWithCharacter(charactersToSearch, characterToFind) '' 5 Stack Longs

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Checks if the string of characters ends with the specified character.                                                    │
'' │                                                                                                                          │
'' │ Returns true if yes and false if no.                                                                                     │
'' │                                                                                                                          │
'' │ CharactersToSearch - A pointer to the string of characters to search.                                                    │                                                           
'' │ CharacterToFind    - The character to find in the string of characters to search.                                        │                                                                           
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  return (byte[charactersToSearch + strsize(charactersToSearch) - 1] == characterToFind)

PUB endsWithCharacters(charactersToSearch, charactersToFind)

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Checks if the string of characters ends with the specified characters.                                                   │
'' │                                                                                                                          │
'' │ Returns true if yes and false if no.                                                                                     │
'' │                                                                                                                          │
'' │ CharactersToSearch - A pointer to the string of characters to search.                                                    │                                                           
'' │ CharactersToFind   - A pointer to the string of characters to find in the string of characters to search.                │                                                                           
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  return ((charactersToSearch + (strsize(charactersToSearch) - strsize(charactersToFind)) - 2) == findCharacters(charactersToSearch, charactersToFind)) 

PUB findCharacterFromEnd(charactersToSearch, characterToFind) | p
  p := charactersToSearch + strsize(charactersToSearch)
  repeat while p>charactersToSearch   
   if(byte[p] == characterToFind)
     return p
   --p
     
  return 0

PUB findCharacter(charactersToSearch, characterToFind) '' 5 Stack Longs

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Searches a string of characters for the first occurence of the specified character.                                      │
'' │                                                                                                                          │
'' │ Returns the address of that character if found and zero if not found.                                                    │
'' │                                                                                                                          │
'' │ CharactersToSearch - A pointer to the string of characters to search.                                                    │                                                           
'' │ CharacterToFind    - The character to find in the string of characters to search.                                        │                                                                           
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  repeat strsize(charactersToSearch--)
    if(byte[++charactersToSearch] == characterToFind)    
      return charactersToSearch

PUB replaceCharacter(charactersToSearch, characterToReplace, characterToReplaceWith) '' 11 Stack Longs

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Replaces the first occurence of the specified character in a string of characters with another character.                │
'' │                                                                                                                          │
'' │ Returns the address of the next character after the character replaced on sucess and zero on failure.                    │
'' │                                                                                                                          │
'' │ CharactersToSearch     - A pointer to the string of characters to search.                                                │                                                                    
'' │ CharacterToReplace     - The character to find in the string of characters to search.                                    │                                                                               
'' │ CharacterToReplaceWith - The character to replace the character found in the string of characters to search.             │                                                                                                           
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  result := findCharacter(charactersToSearch, characterToReplace)
  
  if(result)
    byte[result++] := characterToReplaceWith

PUB replaceAllCharacter(charactersToSearch, characterToReplace, characterToReplaceWith) '' 17 Stack Longs

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Replaces all occurences of the specified character in a string of characters with another character.                     │
'' │                                                                                                                          │
'' │ CharactersToSearch     - A pointer to the string of characters to search.                                                │                                                                    
'' │ CharacterToReplace     - The character to find in the string of characters to search.                                    │                                                                               
'' │ CharacterToReplaceWith - The character to replace the character found in the string of characters to search.             │                                                                                                           
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  repeat while(charactersToSearch)
    charactersToSearch := replaceCharacter(charactersToSearch, characterToReplace, characterToReplaceWith)
  
PUB findCharacters(charactersToSearch, charactersToFind) | index '' 6 Stack Longs 

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Searches a string of characters for the first occurence of the specified string of characters.                           │
'' │                                                                                                                          │
'' │ Returns the address of that string of characters if found and zero if not found.                                         │
'' │                                                                                                                          │
'' │ CharactersToSearch - A pointer to the string of characters to search.                                                    │                                                           
'' │ CharactersToFind   - A pointer to the string of characters to find in the string of characters to search.                │                                                                           
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  repeat strsize(charactersToSearch--)
    if(byte[++charactersToSearch] == byte[CharactersToFind])

      repeat index from 0 to (strsize(charactersToFind) - 1)
        if(byte[charactersToSearch][index] <> byte[charactersToFind][index])
          result := true

      ifnot(result~)
        return charactersToSearch

PUB replaceCharacters(charactersToSearch, charactersToReplace, charactersToReplaceWith) '' 12 Stack Longs

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Replaces the first occurence of the specified string of characters in a string of characters with another string of      │
'' │ characters. Will not enlarge or shrink a string of characters.                                                           │
'' │                                                                                                                          │
'' │ Returns the address of the next character after the string of characters replaced on sucess and zero on failure.         │
'' │                                                                                                                          │
'' │ CharactersToSearch      - A pointer to the string of characters to search.                                               │                                                                   
'' │ CharactersToReplace     - A pointer to the string of characters to find in the string of characters to search.           │                                                                                                       
'' │ CharactersToReplaceWith - A pointer to the string of characters that will replace the string of characters found in the  │
'' │                           string of characters to search.                                                                │                                           
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  result := findCharacters(charactersToSearch, charactersToReplace)

  if(result)
    charactersToSearch := strsize(charactersToReplaceWith)
  
    if(strsize(charactersToReplace) < charactersToSearch)
      charactersToSearch := strsize(charactersToReplace)

    repeat charactersToSearch 
      byte[result++] := byte[charactersToReplaceWith++]

PUB replaceAllCharacters(charactersToSearch, charactersToReplace, charactersToReplaceWith) '' 18 Stack Longs

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Replaces all occurences of the specified string of characters in a string of characters with another string of           │
'' │ characters. Will not enlarge or shrink a string of characters.                                                           │
'' │                                                                                                                          │
'' │ CharactersToSearch      - A pointer to the string of characters to search.                                               │                                                                   
'' │ CharactersToReplace     - A pointer to the string of characters to find in the string of characters to search.           │                                                                                                       
'' │ CharactersToReplaceWith - A pointer to the string of characters that will replace the string of characters found in the  │
'' │                           string of characters to search.                                                                │                                           
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  repeat while(charactersToSearch)
    charactersToSearch := replaceCharacters(charactersToSearch, charactersToReplace, charactersToReplaceWith)

PUB trimCharacters(characters) '' 4 Stack Longs

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Removes white space and new lines from the beginning and end of a string of characters.                                  │
'' │                                                                                                                          │
'' │ Returns a pointer to the trimed string of characters.                                                                    │
'' │                                                                                                                          │
'' │ Characters - A pointer to a string of characters to be trimed.                                                           │                                                     
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  repeat while((1 =< byte[characters]) and (byte[characters] =< 32) or (byte[characters] == 127))
    characters++

  result := characters
  characters += (strsize(characters) - 1)
  
  repeat while((1 =< byte[characters]) and (byte[characters] =< 32) or (byte[characters] == 127))
    byte[characters--] := 0    


PUB charactersToLowerCase(characters) '' 4 Stack Longs

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Demotes all upper case characters in the set of ("A","Z") to their lower case equivalents.                               │
'' │                                                                                                                          │
'' │ Characters - A pointer to a string of characters to convert to lowercase.                                                │ 
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  repeat strsize(characters--)
    result := byte[++characters]

    if((result => "A") and (result =< "Z"))    
      byte[characters] := (result + 32)

PUB charactersToUpperCase(characters) '' 4 Stack Longs

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Promotes all lower case characters in the set of ("a","z") to their upper case equivalents.                              │
'' │                                                                                                                          │
'' │ Characters - A pointer to a string of characters to convert to uppercase.                                                │ 
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  repeat strsize(characters--)
    result := byte[++characters]

    if((result => "a") and (result =< "z"))    
      byte[characters] := (result - 32)
 
PUB decimalToNumber(characters) | buffer, counter '' 6 Stack Longs.

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Converts a decimal string into an integer number. Expects a trimed, capitalized, and decimal string.                     │
'' │                                                                                                                          │
'' │ Returns the converted integer.                                                                                           │
'' │                                                                                                                          │
'' │ Characters - A pointer to the decimal string to convert.                                                                 │
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  buffer := byte[characters]
  characters -= (buffer == "-")
  counter := (strsize(characters) <# 10)

  repeat while(counter--)
    result *= 10
    result += lookdownz(byte[characters++]: "0".."9")

  if(buffer == "-")
    -result   
      
PUB hexadecimalToNumber(characters) | index '' 5 Stack Longs.

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Converts a hexadecimal string into an integer number. Expects a trimed, capitalized, and hexadecimal string.             │ 
'' │                                                                                                                          │
'' │ Returns the converted integer.                                                                                           │
'' │                                                                                                                          │
'' │ Characters - A pointer to the hexadecimal string to convert.                                                             │
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  index := (strsize(characters) <# 8)

  repeat while(index--)
    result <<= 4
    result += lookdownz(byte[characters++]: "0".."9", "A".."F")    

PUB binaryToNumber(characters) | index '' 5 Stack Longs.

'' ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
'' │ Converts a binary string into an integer number. Expects a trimed, capitalized, and binary string.                       │
'' │                                                                                                                          │
'' │ Returns the converted integer.                                                                                           │
'' │                                                                                                                          │
'' │ Characters - A pointer to the binary string to convert.                                                                  │
'' └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  index := (strsize(characters) <# 32)

  repeat while(index--)
    result <<= 1
    result += lookdownz(byte[characters++]: "0", "1")

PUB equals(p1,p2)
'
'' This utility function compares two strings.
  repeat
    if byte[p1]<>byte[p2]
      return false      
    if (byte[p1]==0) and (byte[p2]==0)
      return true
    ++p1
    ++p2

PUB numberToString(value, buffer) | i, x, p '' 5 Stack Longs

  p := buffer

  x := value == NEGX                                                            'Check for max negative
  if value < 0
    value := ||(value+x)                                                        'If negative, make positive; adjust for max negative
    byte[p++] := "-"                                                            'and output sign

  i := 1_000_000_000                                                            'Initialize divisor

  repeat 10                                                                     'Loop for 10 digits
    if value => i                                                               
      byte[p++] := value / i + "0" + x*(i == 1)                                 'If non-zero digit, output digit; adjust for max negative
      value //= i                                                               'and digit from value
      result~~                                                                  'flag non-zero found
    elseif result or i == 1                        
      byte[p++] := "0"                                                            'If zero digit (or only digit) output it
    i /= 10                                                                     'Update divisor

  byte[p] := 0
  return buffer   

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