unit CharManipulation;
interface

const
  CHAR_BITS = 8;
  MAX_CHAR = (1 << CHAR_BITS) - 1;

function GetLo(c : cardinal) : char;
function GetHi(c : cardinal) : char; 
function Combine(hi, lo : char) : cardinal;

implementation

function GetLo(c : cardinal) : char;
begin
  exit (char(c and MAX_CHAR));
end;

function GetHi(c : cardinal) : char;
begin
  exit (char((c >> CHAR_BITS) and MAX_CHAR));
end;

function Combine(hi, lo : char) : cardinal;
begin
  exit ((cardinal(hi) << CHAR_BITS) or cardinal(lo));
end;

end.