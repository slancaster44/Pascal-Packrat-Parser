{$ifndef __BYTE_MANIP_INC__}
{$define __BYTE_MANIP_INC__}

const
  CHAR_BITS = 8;
  MAX_CHAR = (1 << CHAR_BITS) - 1;

function GetLo(c : cardinal) : char; forward;
function GetHi(c : cardinal) : char; forward;
function Combine(hi, lo : char) : cardinal; forward;

{$ifdef __IMPL__}

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

{$endif}
{$endif}