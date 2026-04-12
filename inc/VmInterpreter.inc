{$ifndef __VM_INTERP_INC__}
{$define __VM_INTERP_INC__}

{$include inc/File.inc}

const
  MAX_VM_SP = 255;

type
  ParseVmStackPointer = 0..MAX_VM_SP;

  ParseState = record
    success : boolean;
    start, stop : cardinal;
  end;

  ParseMemo = record
    next : ^ParseMemo;
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

    memos : pParseMemo;
  end;
  pParseVm = ^ParseVm;

function NewParserVm(cmd, src : pTextFile) : ParseVm; forward;
function Parse(vm : pParseVm) : ParseState; forward;
function CompareStates(s0, s1 : ParseState) : boolean; forward;

{$ifdef __IMPL__}
{$include inc/VmCommands.inc}
{$include inc/ByteManip.inc}
{$include inc/Memory.inc}

function DEFAULT_STATE() : ParseState;
var
  output : ParseState;
begin
  output.success := false;
  output.start := 0;
  output.stop := 0;
  exit(output);
end;

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
  output.memos := nil;

  exit (output);
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
    foundMemo : pParseMemo;

    procedure _searchMemos();
    begin
      foundMemo := vm^.memos;
      while foundMemo <> nil do
        begin
          if 
            (foundMemo^.callAddr = addr) and
            (foundMemo^.callInpLoc = FileGetPosition(vm^.inputFile))
          then exit;

          foundMemo := foundMemo^.next;
        end;
    end;
  begin

    _searchMemos();
    if (foundMemo <> nil) then
      begin
        FileSeek(vm^.inputFile, foundMemo^.retInpLoc);
        PushState(foundMemo^.retState);
        exit;
      end;

    Assert(vm^.returnPointer < MAX_VM_SP, 'return overflow', 15);
    rec.memo.callAddr := addr;
    rec.memo.callInpLoc := FileGetPosition(vm^.inputFile);
    rec.memo.retState := DEFAULT_STATE();
    rec.returnToAddr := FileGetPosition(vm^.commandFile);
    vm^.returnStack[vm^.returnPointer] := rec;
    vm^.returnPointer := vm^.returnPointer + 1;
    FileSeek(vm^.commandFile, addr);
  end;

  procedure Return();
  var
    newMemo : pParseMemo;
  begin
    Assert(vm^.returnPointer <> 0, 'return underflow', 16);
    newMemo := pParseMemo(MemoryAllocate(sizeof(ParseMemo)));
    newMemo^ := vm^.returnStack[vm^.returnPointer-1].memo;
    newMemo^.retState := vm^.stateStack[vm^.statePointer-1];
    newMemo^.retInpLoc := FileGetPosition(vm^.inputFile);

    newMemo^.next := vm^.memos;
    vm^.memos := newMemo;
    
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

      if command = char(2) then
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
    (not IsFileEof(vm^.inputFile)) and
    (((cardinal(command) and 1) = 0) and 
    ((not hasPreviousState) or (prevState.success)))
  then
    begin
      call_addr := Combine(next_cmd, command);
      if hasPreviousState then PushState(prevState);     
      Call(call_addr);
    end
  else if { Call if not state }
    (not IsFileEof(vm^.inputFile)) and
    ((cardinal(command) and 1) = 1) and 
    ((hasPreviousState) and (not prevState.success))
  then
    begin
      call_addr := Combine(next_cmd, command) and (not 1);
      Call(call_addr);
    end
  else { Otherwise, pass on previous result }
    begin
      PushState(prevState);
      Return();
    end;

end;

function Parse(vm : pParseVm) : ParseState;
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

  exit (vm^.stateStack[vm^.statePointer-1]);
end;

{$endif}
{$endif}