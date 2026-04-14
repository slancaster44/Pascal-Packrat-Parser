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

  ParseVm = record
    commandFile : pTextFile;
    inputFile : pTextFile;

    statePointer : ParseVmStackPointer;
    stateStack : array [ParseVmStackPointer] of ParseState;

    returnPointer : ParseVmStackPointer;
    returnStack : array [ParseVmStackPointer] of ReturnRecord;

    memos : array [ParseMemoPointer] of ParseMemo;
    memoPointer : ParseMemoPointer;
    memoHasWrapped : boolean;
  end;
  pParseVm = ^ParseVm;

function NewParserVm(cmd, src : pTextFile) : ParseVm; forward;
procedure Parse(vm : pParseVm); forward;
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

function NewParserVm(cmd, src : pTextFile) : ParseVm;
var
  output : ParseVm;
begin
  Assert(cmd^.mode = FMODE_READ, 'vm command file should be readable', 34);
  Assert(src^.mode = FMODE_READ, 'vm source file should be readable', 33);

  output.commandFile := cmd;
  output.inputFile := src;
  output.statePointer := 0;
  output.returnPointer := 0;
  output.memoPointer := 0;
  output.memoHasWrapped := false;

  exit (output);
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



procedure _singleStep(vm : pParseVm);

  function ReadCommand() : char;
  begin
    exit (FileRead(vm^.commandFile));
  end;

  function ReadInput() : char;
  begin
    exit (FileRead(vm^.inputFile));
  end;

  procedure PushState(state : ParseState);
  begin
    Assert(vm^.statePointer < MAX_VM_SP, 'state overflow', 14);
    vm^.stateStack[vm^.statePointer] := state;
    vm^.statePointer := vm^.statePointer + 1;
  end;

  function PopState(): ParseState;
  var
    output : ParseState;
  begin
    Assert(vm^.statePointer <> 0, 'state underflow', 15);
    vm^.statePointer := vm^.statePointer - 1;
    output := vm^.stateStack[vm^.statePointer];
    exit (output);
  end;

  procedure Call(addr : cardinal);
  var
    rec : ReturnRecord;
    foundMemoIdx : integer;
  begin

    foundMemoIdx := LookupMemo(vm, addr);
    if (foundMemoIdx > 0) then
      begin
        FileSeek(vm^.inputFile, vm^.memos[foundMemoIdx].retInpLoc);
        PushState(vm^.memos[foundMemoIdx].retState);
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

  procedure Return();
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

var
  command, next_cmd, input : char;
  call_addr : cardinal;
  hasPreviousState, isEof : boolean;
  prevState, newState : ParseState;
begin
  command := ReadCommand();

  if command = VM_COMMAND_RET then
    begin { A sequence has succeeded, combine two components }
      command := ReadCommand();
      
      if (command = char(2)) and (vm^.statePointer >= 2) then
        begin
          newState := PopState();
          prevState := PopState();
          newState.success := newState.success and prevState.success;
          newState.start := prevState.start;
          PushState(newState);
        end;

      Return();
      exit;
    end;
  if (command = VM_COMMAND_RANGE) and (not IsFileEof(vm^.inputFile)) then
    begin
      command := ReadCommand();
      command := ReadCommand();
      isEof := IsFileEof(vm^.inputFile);

      newState.start := FileGetPosition(vm^.inputFile);

      input := ReadInput();
      newState.stop := FileGetPosition(vm^.inputFile);
      if IsFileEof(vm^.inputFile) then newState.stop := FileLength(vm^.inputFile);
      
      newState.success := (not isEof) and (input >= command);
      command := ReadCommand();
      newState.success := newState.success and (input <= command);

      PushState(newState);
      Return();
      exit;
    end;

  next_cmd := ReadCommand();
  hasPreviousState := vm^.statePointer <> 0;
  if hasPreviousState then 
    begin
      prevState := PopState();
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
      if hasPreviousState then PushState(prevState);     
      Call(call_addr);
    end
  else if { Call if not state }
    ((cardinal(command) and 1) = 1) and 
    (not IsFileEof(vm^.inputFile)) and
    ((hasPreviousState) and (not prevState.success))
  then
    begin
      call_addr := Combine(next_cmd, command) and (not 1);
      Call(call_addr);
    end
  else { Otherwise, pass on previous result }
    begin
      PushState(prevState);
    end;
end;

procedure Parse(vm : pParseVm);
var
  lo, hi : char;
begin
  FileSeek(vm^.commandFile, 0);

  lo := FileRead(vm^.commandFile);
  hi := FileRead(vm^.commandFile);
  FileSeek(vm^.commandFile, Combine(hi, lo));

  vm^.returnStack[vm^.returnPointer].returnToAddr := 0;
  vm^.returnPointer := 1;

  while (FileGetPosition(vm^.commandFile)) <> 0 do 
    begin
      _singleStep(vm);
    end;
end;

{$endif}
{$endif}