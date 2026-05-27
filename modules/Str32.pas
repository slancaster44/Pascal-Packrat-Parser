unit Str32;
interface

type
  acRawStr = array [0..31] of char;

function FreeStrToRawStr(freeS : pChar; freeLen : cardinal) : acRawStr;
{TODO: String interning?}

implementation

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

end.