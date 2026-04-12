{$ifndef __MEMORY_INC__}
{$define __MEMORY_INC__}

type
  pointer = ^char;

function MemoryAllocate(size : cardinal) : pointer; forward;
procedure MemoryDeallocate(p : pointer); forward;

{$ifdef __IMPL__}
{$define __IMPL__}

function MemoryAllocate(size : cardinal) : pointer;
var
  output : pointer;
begin
  GetMem(output, size);
  exit (output);
end;

procedure MemoryDeallocate(p : pointer);
begin
  FreeMem(p);
end;

{$endif}
{$endif}