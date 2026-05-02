unit ParserCompiler;
interface

uses ParserCombinators, CursorBuffer;

procedure CompileParser(cb : pCursorBuffer; p : pParser);

implementation

uses ParserBytecode, Assertion, CharManipulation;

function GetCompileSize(p : pParser) : cardinal;
begin
  case (p^.kind) of
    PARSER_RANGE: exit (ParserInstructionLength(PARSE_OP_RANGE));
    PARSER_SEQUENCE: exit (ParserInstructionLength(PARSE_OP_SEQ));
    PARSER_ALTERNATIVE: exit (ParserInstructionLength(PARSE_OP_ALT));
    PARSER_RESULT: exit (ParserInstructionLength(PARSE_OP_RES));
  else
    MakeAssertion(false, 'Unknown parser type, length');
  end;
end;

function GetCompilePosition(p : pParser) : cardinal;
var
  loc : cardinal;
  curParser : pParser;
begin
  MakeAssertion(IsParserValid(p), 'Cannot compile invalid/deleted parser');
  loc := 2;
  curParser := GetAllParsers();

  while curParser <> p do
    begin
      if curParser^.mark then loc := loc + GetCompileSize(p);
      curParser := curParser^.next;
    end;

  exit (loc);
end;

procedure DoCompile(cb : pCursorBuffer; p : pParser);
var
  loc, left_loc, right_loc : cardinal;
begin
  if p^.mark = false then exit;
  p^.mark := false;

  loc := GetCompilePosition(p);
  CursorBufferSeek(cb, loc);

  if p^.kind = PARSER_RANGE then
    begin
      WriteParseOpRange(cb, p^.min_char, p^.max_char);
    end
  else if p^.kind = PARSER_SEQUENCE then
    begin
      left_loc := GetCompilePosition(p^.left);
      right_loc := GetCompilePosition(p^.right);
      WriteParseOpSequence(cb, left_loc, right_loc);
      DoCompile(cb, p^.left);
      DoCompile(cb, p^.right);
    end
  else if p^.kind = PARSER_ALTERNATIVE then
    begin
      left_loc := GetCompilePosition(p^.left);
      right_loc := GetCompilePosition(p^.right);
      WriteParseOpAlt(cb, left_loc, right_loc);
      DoCompile(cb, p^.left);
      DoCompile(cb, p^.right);
    end
  else if p^.kind = PARSER_RESULT then
    begin
      left_loc := GetCompilePosition(p^.child);
      WriteParseOpResult(cb, left_loc);
      DoCompile(cb, p^.child);
    end
  else
    begin
      MakeAssertion(false, 'unhandled parser to compile');
    end;
end;

procedure CompileParser(cb : pCursorBuffer; p : pParser);
var
  loc : cardinal;
begin
  MakeAssertion(IsParserValid(p), 'Cannot compile invalid/deleted parser');

  ParserUnmarkAll();
  ParserMarkAllChildrenOf(p); { for optimization, only compile children }

  loc := GetCompilePosition(p);

  CursorBufferSeek(cb, 0);
  CursorBufferWrite(cb, GetHi(loc));
  CursorBufferWrite(cb, GetLo(loc));

  DoCompile(cb, p);
end;

end.