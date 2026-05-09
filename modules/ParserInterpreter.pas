unit ParserInterpreter;
interface

uses CursorBuffer, Memory;

type
  rParseResult = record
    identifier : cardinal;
    start, stop : cardinal;
    child, sibling : ^rParseResult;
  end;
  pParseResult = ^rParseResult;
  ppParseResult = ^pParseResult;

  rParseMemo = record
    next : ^rParseMemo;
    inpLoc, cmdLoc : cardinal;
    inpConsumedLocation : cardinal;
    output : boolean;
    resOut : pParseResult;
  end;
  pParseMemo = ^rParseMemo;

  rParserInterpreter = record
    parseArena : rAllocator;
    memos : pParseMemo;
    inp, cmd : pCursorBuffer;
  end;
  pParserInterpreter = ^rParserInterpreter;

procedure InitParserInterpreter
  (p : pParserInterpreter; inputText, parserCode : pCursorBuffer);
function Parse(p : pParserInterpreter; res : ppParseResult) : boolean;
procedure PrintParseResult(res : pParseResult; tabCount : cardinal);

implementation

uses ParserBytecode, Assertion, CharManipulation;

procedure InitParserInterpreter
  (p : pParserInterpreter; inputText, parserCode : pCursorBuffer);
begin
  p^.inp := inputText;
  p^.cmd := parserCode;
  p^.memos := nil;
  InitAllocator(@(p^.parseArena));
end;

function LookupMemo(p : pParserInterpreter) : pParseMemo;
var
  inpLoc, cmdLoc : cardinal;
  curMemo : pParseMemo;
begin
  inpLoc := CursorBufferPosition(p^.inp);
  cmdLoc := CursorBufferPosition(p^.cmd);
  curMemo := p^.memos;
  while (curMemo <> nil) do
    begin
      if
        (curMemo^.inpLoc = inpLoc) and
        (curMemo^.cmdLoc = cmdLoc)
      then exit (curMemo);
      curMemo := curMemo^.next;
    end;
  exit (nil);
end;

function NewMemo(p : pParserInterpreter) : pParseMemo;
var
  memo : pParseMemo;
begin
  memo := pParseMemo(AllocatorAllocate(@(p^.parseArena), sizeof(rParseMemo)));
  memo^.inpLoc := CursorBufferPosition(p^.inp);
  memo^.cmdLoc := CursorBufferPosition(p^.cmd);
  exit (memo);
end;

procedure FinalizeMemo
  (p : pParserInterpreter; m : pParseMemo; res : boolean; pres : pParseResult);
begin
  m^.inpConsumedLocation := CursorBufferPosition(p^.inp);
  m^.output := res;
  m^.resOut := pres;
  m^.next := p^.memos;
  p^.memos := m;
end;

function ParserEx(p : pParserInterpreter; parseRes : ppParseResult) : boolean;
var
  lo, hi, lo_left, hi_left, lo_right, hi_right, inp : char;
  old_inp_pos, identifier, start, stop : cardinal;
  res : boolean;
  cmd : ParserOpcode;
  childRes, siblingRes, tmpRes : pParseResult;
  memo : pParseMemo;
begin
  memo := LookupMemo(p);
  if (memo <> nil) then
    begin
      parseRes^ := memo^.resOut;
      CursorBufferSeek(p^.inp, memo^.inpConsumedLocation);
      exit (memo^.output);
    end;
  memo := NewMemo(p);

  cmd := ParserOpcode(CursorBufferRead(p^.cmd));
  childRes := nil;
  siblingRes := nil;
  res := false;
  old_inp_pos := CursorBufferPosition(p^.inp);

  if cmd = PARSE_OP_RANGE then
    begin
      lo := CursorBufferRead(p^.cmd);
      hi := CursorBufferRead(p^.cmd);
      if CursorBufferEnd(p^.inp) then 
        res := (false)
      else
        begin
          inp := CursorBufferRead(p^.inp);
          res := ((cardinal(lo) <= cardinal(inp)) and 
            (cardinal(hi) >= cardinal(inp)));
        end;
    end
  else if cmd = PARSE_OP_SEQ then
    begin
      hi_left := CursorBufferRead(p^.cmd);
      lo_left := CursorBufferRead(p^.cmd);
      hi_right := CursorBufferRead(p^.cmd);
      lo_right := CursorBufferRead(p^.cmd);

      CursorBufferSeek(p^.cmd, Combine(hi_left, lo_left));
      res := ParserEx(p, @childRes);
      
      CursorBufferSeek(p^.cmd, Combine(hi_right, lo_right));
      if res then res := ParserEx(p, @siblingRes);
      if (res) and (childRes <> nil) then 
        begin
          tmpRes := childRes;
          while (tmpRes^.sibling <> nil) do tmpRes := tmpRes^.sibling;
          tmpRes^.sibling := siblingRes;
        end;
    end
  else if cmd = PARSE_OP_ALT then
    begin
      hi_left := CursorBufferRead(p^.cmd);
      lo_left := CursorBufferRead(p^.cmd);
      hi_right := CursorBufferRead(p^.cmd);
      lo_right := CursorBufferRead(p^.cmd);

      CursorBufferSeek(p^.cmd, Combine(hi_left, lo_left));
      res := ParserEx(p, @childRes);
      
      CursorBufferSeek(p^.cmd, Combine(hi_right, lo_right));
      if not res then 
        begin
          childRes := nil;
          res := ParserEx(p, @childRes);
        end;
    end
  else if cmd = PARSE_OP_RES then
    begin
      identifier := CursorBufferPosition(p^.cmd)-1; { -1, to account for cmd read }
      hi := CursorBufferRead(p^.cmd);
      lo := CursorBufferRead(p^.cmd);
      CursorBufferSeek(p^.cmd, Combine(hi, lo));

      start := CursorBufferPosition(p^.inp);
      parseRes^ := pParseResult(
        AllocatorAllocate(@(p^.parseArena), sizeof(rParseResult)));
      parseRes^^.identifier := identifier;
      parseRes^^.start := start;
      parseRes^^.sibling := nil;
      parseRes^^.child := nil;

      res := ParserEx(p, @childRes);
      stop := CursorBufferPosition(p^.inp);
      parseRes^^.stop := stop;
    end
  else
    MakeAssertion(false, 'Interpreter, unimplemented instruction');

  if (res) and (childRes <> nil) then
    begin
      if (parseRes^) = nil then
        parseRes^ := childRes
      else
        parseRes^^.child := childRes;
    end;
  
  if not res then CursorBufferSeek(p^.inp, old_inp_pos);
  FinalizeMemo(p, memo, res, parseRes^);
  exit (res);
end;

function Parse(p : pParserInterpreter; res : ppParseResult) : boolean;
var
  hi, lo : char;
begin
  MakeAssertion(res <> nil, 'Cannot have nil for parser result output');
  res^ := nil;

  DestroyAllocator(@(p^.parseArena));
  InitAllocator(@(p^.parseArena));
  p^.memos := nil;

  CursorBufferSeek(p^.cmd, 0);
  lo := CursorBufferRead(p^.cmd);
  hi := CursorBufferRead(p^.cmd);
  CursorBufferSeek(p^.cmd, Combine(hi, lo));
  exit (ParserEx(p, res));
end;

procedure PrintParseResult(res : pParseResult; tabCount : cardinal);
var
  i : cardinal;
begin
  if res = nil then exit;
  for i := 1 to tabCount do 
    begin
      write('|');
      write(char(9));
    end;

  write('|- ');
  write(res^.identifier);
  write(' (');
  write(res^.start);
  write(',');
  write(res^.stop);
  write(')');
  writeln();

  PrintParseResult(res^.child, tabCount+1);
  PrintParseResult(res^.sibling, tabCount);
end;

end.