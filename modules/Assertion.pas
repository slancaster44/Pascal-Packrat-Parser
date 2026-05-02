unit Assertion;
interface

uses Str32;

procedure MakeAssertion(cond : boolean; msg : acRawStr);

implementation

procedure MakeAssertion(cond : boolean; msg : acRawStr);
begin
  if not cond then
    begin
      writeln(msg);
      halt();
    end;
end;

end.
