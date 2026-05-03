unit ParserInterpreter;
interface

uses CursorBuffer;

type
  rParserInterpreter = record
    inp, cmd : pCursorBuffer;
  end;
  pParserInterpreter = ^rParserInterpreter;

procedure InitParserInterpreter
  (p : pParserInterpreter; inputText, parserCode : pCursorBuffer);
function Parse(p : pParserInterpreter) : boolean;

implementation

uses ParserBytecode, Assertion, CharManipulation;

procedure InitParserInterpreter
  (p : pParserInterpreter; inputText, parserCode : pCursorBuffer);
begin
  p^.inp := inputText;
  p^.cmd := parserCode;
end;

function ParserEx(p : pParserInterpreter) : boolean;
var
  lo, hi, lo_left, hi_left, lo_right, hi_right, inp : char;
  res : boolean;
  cmd : ParserOpcode;
begin
  cmd := ParserOpcode(CursorBufferRead(p^.cmd));

  if cmd = PARSE_OP_RANGE then
    begin
      lo := CursorBufferRead(p^.cmd);
      hi := CursorBufferRead(p^.cmd);
      if CursorBufferEnd(p^.inp) then exit (false);
      
      inp := CursorBufferRead(p^.inp);
      exit ((cardinal(lo) <= cardinal(inp)) and (cardinal(hi) >= cardinal(inp)));
    end
  else if cmd = PARSE_OP_SEQ then
    begin
      hi_left := CursorBufferRead(p^.cmd);
      lo_left := CursorBufferRead(p^.cmd);
      hi_right := CursorBufferRead(p^.cmd);
      lo_right := CursorBufferRead(p^.cmd);

      CursorBufferSeek(p^.cmd, Combine(hi_left, lo_left));
      res := ParserEx(p);
      
      CursorBufferSeek(p^.cmd, Combine(hi_right, lo_right));
      if res then res := ParserEx(p);
      
      exit (res);
    end
  else
    MakeAssertion(false, 'Interpreter, unimplemented instruction');
end;

function Parse(p : pParserInterpreter) : boolean;
var
  hi, lo : char;
begin
  CursorBufferSeek(p^.cmd, 0);
  lo := CursorBufferRead(p^.cmd);
  hi := CursorBufferRead(p^.cmd);
  CursorBufferSeek(p^.cmd, Combine(hi, lo));
  exit (ParserEx(p));
end;

end.