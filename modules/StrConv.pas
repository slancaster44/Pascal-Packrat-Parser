unit StrConv;
interface

function StrToInt(s : pChar; slen : cardinal; base : cardinal) : cardinal;

implementation
uses Assertion;

function StrToInt(s : pChar; slen : cardinal; base : cardinal) : cardinal;
var
	curChar : cardinal;
	res, place, i : cardinal;
begin
	res := 0;
	place := 1;

	if slen <> 0 then
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
					MakeAssertion(false, 'Invalid character for integer conversion');

				MakeAssertion(curChar < base, 'Character in integer out of range for base');

				res := res + (curChar * place);
				place := place * base;
			end;

	exit (res);
end;

end.