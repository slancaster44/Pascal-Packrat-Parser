unit Memory;
interface

uses Assertion;

type
  rAllocation = record
    next : ^rAllocation;
    mark : boolean;
    memory : pointer;
  end;
  pAllocation = ^rAllocation;

  rAllocator = record
    allocations : pAllocation;
  end;
  pAllocator = ^rAllocator;

function MemoryAllocate(size : cardinal) : pointer; 
procedure MemoryDeallocate(p : pointer); 

procedure InitAllocator(a : pAllocator); 
procedure DestroyAllocator(a : pAllocator); 

function AllocatorAllocate(a : pAllocator; size : cardinal) : pointer; 
procedure AllocatorFree(a : pAllocator; mem : pointer); 

procedure AllocatorUnmarkAll(a : pAllocator); 
procedure AllocatorMarkMemory(a : pAllocator; mem : pointer); 
procedure AllocatorFreeUnmarked(a : pAllocator);

implementation

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

procedure InitAllocator(a : pAllocator);
begin
  a^.allocations := nil;
end;

procedure DestroyAllocator(a : pAllocator);
var
  toFree : pAllocation;
begin
  while (a^.allocations <> nil) do
    begin
      toFree := a^.allocations;
      a^.allocations := a^.allocations^.next;
      MemoryDeallocate(pointer(toFree^.memory));
      MemoryDeallocate(pointer(toFree));
    end;
end;

function AllocatorAllocate(a : pAllocator; size : cardinal) : pointer;
var
  newAlloc : pAllocation;
begin
  newAlloc := pAllocation(MemoryAllocate(sizeof(rAllocation)));
  newAlloc^.mark := false;
  newAlloc^.next := a^.allocations;
  newAlloc^.memory := MemoryAllocate(size);
  a^.allocations := newAlloc;
  exit (newAlloc^.memory);
end;

procedure AllocatorFree(a : pAllocator; mem : pointer);
var
  last : pAllocation;
  curAlloc : pAllocation;
begin
  last := nil;
  curAlloc := a^.allocations;

  while 
    (curAlloc <> nil) and
    (curAlloc^.memory <> mem)
  do
    begin
      last := curAlloc;
      curAlloc := curAlloc^.next;
    end;

  MakeAssertion(curAlloc <> nil, 'No such allocation. Double free?');
  
  if last = nil then
    a^.allocations := a^.allocations^.next
  else
    last^.next := curAlloc^.next;

  MemoryDeallocate(pointer(curAlloc^.memory));
  MemoryDeallocate(pointer(curAlloc));
end;

procedure AllocatorUnmarkAll(a : pAllocator);
var
  curAlloc : pAllocation;
begin
  curAlloc := a^.allocations;
  while curAlloc <> nil do
    begin
      curAlloc^.mark := false;
      curAlloc := curAlloc^.next;
    end;
end;

procedure AllocatorMarkMemory(a : pAllocator; mem : pointer);
var
  curAlloc : pAllocation;
begin
  curAlloc := a^.allocations;
  while curAlloc <> nil do
    begin
      if curAlloc^.memory = mem then
        begin
          curAlloc^.mark := true;
          exit;
        end;
      
      curAlloc := curAlloc^.next;
    end;
end;

procedure AllocatorFreeUnmarked(a : pAllocator);
var
  last, curAlloc : pAllocation;
begin
  last := nil;
  curAlloc := a^.allocations;

  while 
    (curAlloc <> nil)
  do
    begin
      if (not curAlloc^.mark) then
        begin
          if last = nil then
            a^.allocations := a^.allocations^.next
          else
            last^.next := curAlloc^.next;

          MemoryDeallocate(pointer(curAlloc^.memory));
          MemoryDeallocate(pointer(curAlloc));

          if last = nil then
            curAlloc := a^.allocations
          else
            curAlloc := last^.next;
        end
      else
        begin
          last := curAlloc;
          curAlloc := curAlloc^.next;
        end;
    end;
end;

end.