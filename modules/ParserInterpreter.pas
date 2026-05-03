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

function SingleStep(p : pParserInterpreter) : boolean;
var
  lo, hi, inp : char;
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
  exit (SingleStep(p));
end;

end.