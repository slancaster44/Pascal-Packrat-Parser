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

var
  curLoc : cardinal;
procedure ParserMarkAllChildrenOf(p : pParser);
begin
  if p^.mark then
    exit;

  p^.mark := true;
  p^.location := curLoc;
  curLoc := curLoc + GetCompileSize(p);

  if (p^.kind = PARSER_ALTERNATIVE) or (p^.kind = PARSER_SEQUENCE) then  
    begin
      ParserMarkAllChildrenOf(p^.left);
      ParserMarkAllChildrenOf(p^.right);
    end
  else if (p^.kind = PARSER_RESULT) then
    begin
      ParserMarkAllChildrenOf(p^.child)
    end;
end;

procedure ParserUnmarkAll();
var
  p : pParser;
begin
  p := GetAllParsers();

  while p <> nil do
    begin
      p^.mark := false;
      p := p^.next;
    end;
end;

procedure DoCompile(cb : pCursorBuffer; p : pParser);
var
  loc, left_loc, right_loc : cardinal;
begin
  if p^.mark = false then exit;
  p^.mark := false;
  CursorBufferSeek(cb, p^.location);

  if p^.kind = PARSER_RANGE then
    begin
      WriteParseOpRange(cb, p^.min_char, p^.max_char);
    end
  else if p^.kind = PARSER_SEQUENCE then
    begin
      left_loc := p^.left^.location;
      right_loc := p^.right^.location;
      WriteParseOpSequence(cb, left_loc, right_loc);
      DoCompile(cb, p^.left);
      DoCompile(cb, p^.right);
    end
  else if p^.kind = PARSER_ALTERNATIVE then
    begin
      left_loc := p^.left^.location;
      right_loc := p^.right^.location;
      WriteParseOpAlt(cb, left_loc, right_loc);
      DoCompile(cb, p^.left);
      DoCompile(cb, p^.right);
    end
  else if p^.kind = PARSER_RESULT then
    begin
      loc := p^.child^.location;
      WriteParseOpResult(cb, loc);
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
  { Global we need to set for determining parser bytecode addresses }
  curLoc := 2; {TODO: Should we have a context record for this }

  MakeAssertion(IsParserValid(p), 'Cannot compile invalid/deleted parser');

  ParserUnmarkAll();
  ParserMarkAllChildrenOf(p); { for optimization, only compile children }

  loc := p^.location;

  CursorBufferSeek(cb, 0);
  CursorBufferWrite(cb, GetLo(loc));
  CursorBufferWrite(cb, GetHi(loc));

  DoCompile(cb, p);
end;

end.