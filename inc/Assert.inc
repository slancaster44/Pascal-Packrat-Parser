{$ifndef __ASSERT_INC__}
{$define __ASSERT_INC__}

procedure Assert(cond : boolean; msg : pChar; msglen : cardinal); forward;

{$ifdef __IMPL__}

procedure Assert(cond : boolean; msg : pChar; msglen : cardinal);
var
  i : cardinal;
begin
  if not cond then
    begin
      for i := 0 to msglen do
        write(msg[i]);
      writeln();
      halt;
    end;
end;

{$endif}
{$endif}