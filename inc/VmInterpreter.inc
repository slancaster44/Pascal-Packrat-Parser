{$ifndef __VM_INTERP_INC__}
{$define __VM_INTERP_INC__}

{$include inc/File.inc}

const
  MAX_VM_SP = 255;
  MAX_NUM_MEMOS = 63;

type
  ParseVmStackPointer = 0..MAX_VM_SP;
  ParseMemoPointer = 0..MAX_NUM_MEMOS;

  ParseState = record
    success : boolean;
    start, stop : cardinal;
  end;

  ParseMemo = record
    callAddr, callInpLoc, retInpLoc : cardinal;
    retState : ParseState;
  end;
  pParseMemo = ^ParseMemo;
  
  ReturnRecord = record
    memo : Parsememo;
    returnToAddr : cardinal;
  end;

  ParseTree = record
    id : cardinal;                   {A unique identifier for the parser}
    success : boolean;               {If the node was properly parsed}
    start, stop : cardinal;          {The start and stop location in source}
    siblings, children : ^ParseTree; {The child, and sibling nodes}
  end;
  pParseTree = ^ParseTree;

  ParseVm = record
    commandFile : pTextFile;
    inputFile : pTextFile;

    statePointer : ParseVmStackPointer;
    stateStack : array [ParseVmStackPointer] of ParseState;

    returnPointer : ParseVmStackPointer;
    returnStack : array [ParseVmStackPointer] of ReturnRecord;

    resultPointer : ParseVmStackPointer;
    resultStack : array [ParseVmStackPointer] of pParseTree;

    memos : array [ParseMemoPointer] of ParseMemo;
    memoPointer : ParseMemoPointer;
    memoHasWrapped : boolean;
  end;
  pParseVm = ^ParseVm;

procedure InitializeVm(vm : pParseVm; cmd, src : pTextFile); forward;
function Parse(vm : pParseVm) : pParseTree; forward;
procedure PrintVm(vm : pParseVm); forward;
function CompareStates(s0, s1 : ParseState) : boolean; forward;
procedure PrintState(state : ParseState); forward;

{$ifdef __IMPL__}
{$include inc/VmCommands.inc}
{$include inc/ByteManip.inc}
{$include inc/Memory.inc}

procedure PrintState(state : ParseState);
begin
  write('[');
  write(state.success);
  write(state.start);
  write(state.stop);
  write(']');
end;

procedure PrintVm(vm : pParseVm);
var
  i : cardinal;
begin
  write('Command file location: ');
  writeln(FileGetPosition(vm^.commandFile));
  write('Input file location: ');
  writeln(FileGetPosition(vm^.inputFile));

  writeln('State Stack: ');
  for i := 0 to (vm^.statePointer-1) do
    begin
      write('    ');
      PrintState(vm^.stateStack[i]);
      writeln();
    end;

  writeln('Return Stack: ');
  for i := 0 to (vm^.returnPointer-1) do
    begin
      write(vm^.returnStack[i].returnToAddr);
      writeln();
    end;
  writeln();
end;

function CompareStates(s0, s1 : ParseState) : boolean;
begin
  exit (
    (s0.success = s1.success) and
    (s0.start = s1.start) and
    (s0.stop = s1.stop)
  );
end;

procedure InitializeVm(vm : pParseVm; cmd, src : pTextFile);
begin
  Assert(cmd^.mode = FMODE_READ, 'vm command file should be readable', 34);
  Assert(src^.mode = FMODE_READ, 'vm source file should be readable', 33);

  with vm^ do
    begin
      commandFile := cmd;
      inputFile := src;
      statePointer := 0;
      returnPointer := 0;
      memoPointer := 0;
      memoHasWrapped := false;
    end;
end;

procedure InsertMemo(vm : pParseVm; memo : ParseMemo);
begin
  vm^.memos[vm^.memoPointer] := memo;
  if vm^.memoPointer = MAX_NUM_MEMOS then vm^.memoHasWrapped := true;
  vm^.memoPointer := vm^.memoPointer + 1;
end;

procedure DeleteMemo(vm : pParseVm; idx : cardinal);
begin
  vm^.memoPointer := vm^.memoPointer-1;
  while idx <> vm^.memoPointer do
    begin
      vm^.memos[idx] := vm^.memos[idx+1];
      idx := idx + 1;
    end;
end;

function LookupMemo(vm : pParseVm; callAddr : cardinal) : integer;
var
  tmp : ParseMemo;
  i : integer;
begin
  if vm^.memoPointer = 0 then exit(-1);
  i := (vm^.memoPointer-1);
  if vm^.memoHasWrapped then i := MAX_NUM_MEMOS;
  for i := i downto 0 do
    if 
      (vm^.memos[i].callAddr = callAddr) and
      (vm^.memos[i].callInpLoc = FileGetPosition(vm^.inputFile))
    then
      begin 
        tmp := vm^.memos[i];
        if i <> (vm^.memoPointer-1) then
          begin
            { Move memo to top of buffer }
            { This insures frequently used memos remain in buffer, and }
            { infrequently used memos do not remain in buffer }
            DeleteMemo(vm, i); 
            InsertMemo(vm, tmp);
          end;
        exit(vm^.memoPointer-1);
      end;

  //When a vm is looked up, place at top of stack
  exit (-1);
end;

function ReadCommand(vm : pParseVm) : char;
begin
  exit (FileRead(vm^.commandFile));
end;

function ReadInput(vm : pParseVm) : char;
begin
  exit (FileRead(vm^.inputFile));
end;

function CurrentState(vm : pParseVm) : ParseState;
begin
  Assert(vm^.statePointer <> 0, 'no current state', 16);
  exit (vm^.stateStack[vm^.statePointer-1]);
end;

procedure PushState(vm : pParseVm; state : ParseState);
begin
  Assert(vm^.statePointer < MAX_VM_SP, 'state overflow', 14);
  vm^.stateStack[vm^.statePointer] := state;
  vm^.statePointer := vm^.statePointer + 1;
end;

function PopState(vm : pParseVm): ParseState;
begin
  Assert(vm^.statePointer <> 0, 'state underflow', 15);
  vm^.statePointer := vm^.statePointer - 1;
  exit (vm^.stateStack[vm^.statePointer]);
end;

function CurrentResult(vm : pParseVm): pParseTree;
begin
  if vm^.resultPointer = 0 then exit (nil);
  exit (vm^.resultStack[vm^.resultPointer-1]);
end;

procedure PushResult(vm : pParseVm; res : pParseTree);
  function PopResult(): pParseTree;
  begin
    Assert(vm^.resultPointer <> 0, 'result underflow', 16);
    vm^.resultPointer := vm^.resultPointer - 1;
    exit (vm^.resultStack[vm^.resultPointer]);
  end;
begin
  Assert(vm^.resultPointer < MAX_VM_SP, 'result overflow', 15);
  
  while 
    (vm^.resultPointer <> 0) and
    (CurrentResult(vm)^.start >= res^.start) and
    (CurrentResult(vm)^.stop <= res^.stop)
  do
    begin
      CurrentResult(vm)^.siblings := res^.children;
      res^.children := PopResult();
    end;

  vm^.resultStack[vm^.resultPointer] := res;
  vm^.resultPointer := vm^.resultPointer + 1;
end;

procedure Call(vm : pParseVm; addr : cardinal);
var
  rec : ReturnRecord;
  foundMemoIdx : integer;
begin

  foundMemoIdx := LookupMemo(vm, addr);
  if (foundMemoIdx > 0) then
    begin
      FileSeek(vm^.inputFile, vm^.memos[foundMemoIdx].retInpLoc);
      PushState(vm, vm^.memos[foundMemoIdx].retState);
      exit;
    end;

  Assert(vm^.returnPointer < MAX_VM_SP, 'return overflow', 15);
  rec.memo.callAddr := addr;
  rec.memo.callInpLoc := FileGetPosition(vm^.inputFile);
  rec.returnToAddr := FileGetPosition(vm^.commandFile);
  vm^.returnStack[vm^.returnPointer] := rec;
  vm^.returnPointer := vm^.returnPointer + 1;
  FileSeek(vm^.commandFile, addr);
end;

procedure Return(vm : pParseVm);
var
  newMemo : ParseMemo;
begin
  Assert(vm^.returnPointer <> 0, 'return underflow', 16);
  newMemo := vm^.returnStack[vm^.returnPointer-1].memo;
  newMemo.retState := vm^.stateStack[vm^.statePointer-1];
  newMemo.retInpLoc := FileGetPosition(vm^.inputFile);
  InsertMemo(vm, newMemo);
  
  vm^.returnPointer := vm^.returnPointer - 1;
  FileSeek(vm^.commandFile, vm^.returnStack[vm^.returnPointer].returnToAddr);
end;

procedure _singleStep(vm : pParseVm);
var
  command, next_cmd, input : char;
  call_addr : cardinal;
  hasPreviousState, isEof : boolean;
  prevState, newState : ParseState;
  newRes : pParseTree;
begin
  command := ReadCommand(vm);

  if command = VM_COMMAND_RET then
    begin { A sequence has succeeded, combine two components }
      command := ReadCommand(vm);
      Assert(vm^.statePointer <> 0, 'No state to return', 18);

      if (command = VM_RET_TYPE_SINGLE) then
        Return(vm)
      else if (command = VM_RET_TYPE_DOUBLE) then
        begin
          if (vm^.statePointer >= 2) then
            begin
              newState := PopState(vm);
              prevState := PopState(vm);
              newState.success := newState.success and prevState.success;
              newState.start := prevState.start;
              PushState(vm, newState);
              Return(vm);
            end
          else Return(vm);
        end
      else if (command = VM_RET_MAKE_RESULT) then
        begin
          prevState := CurrentState(vm);
          newRes := pParseTree(MemoryAllocate(sizeof(ParseTree)));
          newRes^.id := FileGetPosition(vm^.commandFile);
          newRes^.success := prevState.success;
          newRes^.start := prevState.start;
          newRes^.stop := prevState.stop;
          newRes^.children := nil;
          newRes^.siblings := nil;
          PushResult(vm, newRes);
          Return(vm);
        end
      else
        begin
          Assert(false, 'illegal instruction', 19);
        end;

      exit;
    end;
  if (command = VM_COMMAND_RANGE) and (not IsFileEof(vm^.inputFile)) then
    begin
      command := ReadCommand(vm);
      command := ReadCommand(vm);
      isEof := IsFileEof(vm^.inputFile);

      newState.start := FileGetPosition(vm^.inputFile);

      input := ReadInput(vm);
      newState.stop := FileGetPosition(vm^.inputFile);
      if IsFileEof(vm^.inputFile) then newState.stop := FileLength(vm^.inputFile);
      
      newState.success := (not isEof) and (input >= command);
      command := ReadCommand(vm);
      newState.success := newState.success and (input <= command);

      PushState(vm, newState);
      Return(vm);
      exit;
    end;

  next_cmd := ReadCommand(vm);
  hasPreviousState := vm^.statePointer <> 0;
  if hasPreviousState then 
    begin
      prevState := PopState(vm);
    end;

  if (hasPreviousState) and (not prevState.success) then
    FileSeek(vm^.inputFile, prevState.start);

  if { Call if state }
    (((cardinal(command) and 1) = 0) and 
    (not IsFileEof(vm^.inputFile)) and
    ((not hasPreviousState) or (prevState.success)))
  then
    begin
      call_addr := Combine(next_cmd, command);
      if hasPreviousState then PushState(vm, prevState);     
      Call(vm, call_addr);
    end
  else if { Call if not state }
    ((cardinal(command) and 1) = 1) and 
    (not IsFileEof(vm^.inputFile)) and
    ((hasPreviousState) and (not prevState.success))
  then
    begin
      call_addr := Combine(next_cmd, command) and (not 1);
      Call(vm, call_addr);
    end
  else { Otherwise, pass on previous result }
    begin
      PushState(vm, prevState);
    end;
end;

function Parse(vm : pParseVm) : pParseTree;
var
  lo, hi : char;
begin
  FileSeek(vm^.commandFile, 0);
  lo := FileRead(vm^.commandFile);
  hi := FileRead(vm^.commandFile);
  
  { Re-initalize things, just in case}
  InitializeVm(vm, vm^.commandFile, vm^.inputFile);
  FileSeek(vm^.commandFile, 0);
  Call(vm, Combine(hi, lo));

  while (FileGetPosition(vm^.commandFile)) <> 0 do 
    begin
      _singleStep(vm);
    end;

  exit (CurrentResult(vm));
end;

{$endif}
{$endif}