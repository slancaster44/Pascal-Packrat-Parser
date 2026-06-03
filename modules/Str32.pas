unit Str32;
interface

type
  acRawStr = array [0..31] of char;

function FreeStrToRawStr(freeS : pChar; freeLen : cardinal) : acRawStr;
function StrToInt(s : acRawStr; base : cardinal) : cardinal;


{TODO: String interning?}

implementation
uses Assertion;

function FreeStrToRawStr(freeS : pChar; freeLen : cardinal) : acRawStr;
var
  trueLen, i : cardinal;
  sigName : acRawStr;
begin
  trueLen := freeLen;
  if trueLen >= sizeof(acRawStr) then trueLen := sizeof(acRawStr)-1;

  if trueLen <> 0 then
    for i := 0 to trueLen-1 do
      sigName[i] := freeS[i];
  sigName[trueLen] := char(0);

  exit (sigName);
end;

function StrToInt(s : acRawStr; base : cardinal) : cardinal;
var
  curChar : cardinal;
  res, place, i, slen : cardinal;
begin
  res := 0;
  place := 1;
  slen := sizeof(acRawStr);

  for i := 0 to slen-1 do
    begin
      curChar := cardinal(s[slen-1-i]);

      if (curChar >= cardinal('0')) and (curChar <= cardinal('9')) then
        curChar := curChar - cardinal('0')
      else if (curChar >= cardinal('a')) and (curChar <= cardinal('z')) then
        curChar := curChar + 10 - cardinal('a')
      else if (curChar >= cardinal('A')) and (curChar <= cardinal('Z')) then
        curChar := curChar + 10 - cardinal('A')
      else
        MakeAssertion(curChar = 0, 'Invalid character for integer conversion');

      if curChar <> 0 then
        begin
          MakeAssertion(curChar < base, 'Character in integer out of range for base');
          res := res + (curChar * place);
          place := place * base;
        end;
    end;

  exit (res);
end;

end.