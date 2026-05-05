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

  rParserInterpreter = record
    parseArena : rAllocator;
    inp, cmd : pCursorBuffer;
  end;
  pParserInterpreter = ^rParserInterpreter;

procedure InitParserInterpreter
  (p : pParserInterpreter; inputText, parserCode : pCursorBuffer);
function Parse(p : pParserInterpreter; res : ppParseResult) : boolean;

implementation

uses ParserBytecode, Assertion, CharManipulation;

procedure InitParserInterpreter
  (p : pParserInterpreter; inputText, parserCode : pCursorBuffer);
begin
  p^.inp := inputText;
  p^.cmd := parserCode;
  InitAllocator(@(p^.parseArena));
end;

function ParserEx(p : pParserInterpreter; parseRes : ppParseResult) : boolean;
var
  lo, hi, lo_left, hi_left, lo_right, hi_right, inp : char;
  old_inp_pos, identifier, start, stop : cardinal;
  res : boolean;
  cmd : ParserOpcode;
  childRes, siblingRes, tmpRes : pParseResult;
begin
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
      identifier := CursorBufferPosition(p^.cmd);
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

  CursorBufferSeek(p^.cmd, 0);
  lo := CursorBufferRead(p^.cmd);
  hi := CursorBufferRead(p^.cmd);
  CursorBufferSeek(p^.cmd, Combine(hi, lo));
  exit (ParserEx(p, res));
end;

end.