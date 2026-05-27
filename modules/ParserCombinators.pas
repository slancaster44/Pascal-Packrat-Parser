unit ParserCombinators;
interface

type
  ParserKind = (
    PARSER_MATCH,         { Tests if character exactly matches }
    PARSER_RANGE,         { Tests if a character is in a given range } 
    PARSER_SEQUENCE,      { Tests if two sub-parsers pass }
    PARSER_ALTERNATIVE,   { Returns the state of the first sub-parser to pass }
    PARSER_KLEENE,        { zero or more instances of the sub-expression }
    PARSER_RESULT,        { Generates a result, given the current state }
    PARSER_PATCHED        { Wrapper parsers for patches }
  );

  rParser = record
    next : ^rParser;

    { For compilation purposes }
    mark : boolean;
    identifier : cardinal;

    case kind : ParserKind of
      PARSER_MATCH : (match_char : char);
      PARSER_RANGE : (min_char, max_char : char);
      PARSER_SEQUENCE, PARSER_ALTERNATIVE : (left, right : ^rParser);
      PARSER_KLEENE, PARSER_RESULT, PARSER_PATCHED : (child : ^rParser);
  end;
  pParser = ^rParser;
  ppParser = ^pParser;

function IsParserValid(p : pParser) : boolean;
function CharacterParser(character : char) : pParser;
function CharacterRangeParser(min, max : char) : pParser;
function SequenceParsers(left, right : pParser) : pParser;
function AlternativeParsers(left, right : pParser) : pParser;
function KleeneParser(child : pParser) : pParser;
function ResultGeneratingParser(child : pParser) : pParser;
function GetAllParsers() : pParser;
procedure ResetParserInternPool();

procedure PatchChild(parent, child : pParser);
procedure PatchRight(parent, child : pParser);
procedure PatchLeft(parent, child : pParser);

implementation 

uses Assertion, Memory;

var
  parserInternPool : pParser;

function GetAllParsers() : pParser;
begin
  exit (parserInternPool);
end;

procedure ResetParserInternPool();
var
  cur, next : pParser;
begin
  cur := parserInternPool;
  while cur <> nil do
    begin
      next := cur^.next;
      MemoryDeallocate(cur);
      cur := next;
    end;
  parserInternPool := nil;
end;

function _parsersMatch(p0, p1 : pParser) : boolean;
  function BothAre(kind : ParserKind) : boolean;
  begin
    exit ((p0^.kind = kind) and (p1^.kind = kind));
  end;

  function ChildrenMatch() : boolean;
  begin { 'nil' indicates a child rParser that will be added later }
    exit (((p0^.left <> nil) and (p1^.left <> nil)) and
      ((p0^.right <> nil) and (p1^.right <> nil)) and
      (p0^.right = p1^.right) and 
      (p0^.left = p1^.left));
  end;

  function ChildMatches() : boolean;
  begin
    exit ((p0^.child <> nil) and (p1^.child <> nil) and
      (p0^.child = p1^.child));
  end;
begin
  exit ((BothAre(PARSER_MATCH) and
    (p0^.match_char = p1^.match_char))
      or
        (BothAre(PARSER_RANGE) and
          ((p0^.min_char) = (p1^.min_char)) and
          ((p0^.max_char) = (p1^.max_char)))
      or
        (BothAre(PARSER_ALTERNATIVE) and ChildrenMatch())
      or
        (BothAre(PARSER_SEQUENCE) and ChildrenMatch())
      or
        ((BothAre(PARSER_RESULT)) and (ChildMatches()))
      or
        ((BothAre(PARSER_KLEENE)) and ChildMatches()));
end;

function _internParser(new_parser : rParser) : pParser;
var
  curParser : pParser;
begin
  curParser := parserInternPool;

  while (curParser <> nil) do
    begin
      if _parsersMatch(curParser, @new_parser) then exit (curParser);
      curParser := curParser^.next;
    end;

  curParser := pParser(MemoryAllocate(sizeof(rParser)));
  curParser^ := new_parser;
  curParser^.next := parserInternPool;
  curParser^.mark := false;
  curParser^.identifier := 0;
  parserInternPool := curParser;
  _internParser := curParser;
  exit (curParser);
end;

function IsParserValid(p : pParser) : boolean;
var
  curParser : pParser;
begin
  curParser := parserInternPool;

  while (curParser <> nil) do
    begin
      if curParser = p then exit (true);
      curParser := curParser^.next;
    end;

  exit (false);
end;

function CharacterParser(character : char) : pParser;
var
  new_parser : rParser;
begin
  new_parser.kind := PARSER_MATCH;
  new_parser.match_char := character;
  exit (_internParser(new_parser));
end;

function CharacterRangeParser(min, max : char) : pParser;
var
  new_parser : rParser;
begin
  new_parser.kind := PARSER_RANGE;
  new_parser.min_char := min;
  new_parser.max_char := max;
  exit (_internParser(new_parser));
end;

function SequenceParsers(left, right : pParser) : pParser;
var
  new_parser : rParser;
begin
  MakeAssertion(IsParserValid(left) 
    or (left = nil), 'Sequence parser, left not valid');
  MakeAssertion(IsParserValid(right)
    or (right = nil), 'Sequence parser, right not valid');

  new_parser.kind := PARSER_SEQUENCE;
  new_parser.left := left;
  new_parser.right := right;
  exit (_internParser(new_parser));
end;

function KleeneParser(child : pParser) : pParser;
var
  new_parser : rParser;
begin
  MakeAssertion(IsParserValid(child) or (child = nil), 
    'Child parser must be valid');

  new_parser.kind := PARSER_KLEENE;
  new_parser.child := child;
  exit (_internParser(new_parser));
end;

function ResultGeneratingParser(child : pParser) : pParser;
var
  new_parser : rParser;
  intern_parser : pParser;
begin
  MakeAssertion(IsParserValid(child) or (child = nil),
    'Child must be valid parser');

  new_parser.kind := PARSER_RESULT;
  new_parser.child := child;
  intern_parser := _internParser(new_parser);
  exit (intern_parser);
end;

function AlternativeParsers(left, right : pParser) : pParser;
var
  new_parser : rParser;
begin
  MakeAssertion(IsParserValid(left)
    or (left = nil), 'Alternative parser, left not valid');
  MakeAssertion(IsParserValid(right)
    or (right = nil), 'Alternative parser, right not valid');
  
  new_parser.kind := PARSER_ALTERNATIVE;
  new_parser.left := left;
  new_parser.right := right;
  exit (_internParser(new_parser));
end;

procedure PatchChild(parent, child : pParser);
var
  new_parser : rParser;
  new_interned : pParser;
begin
  MakeAssertion(parent <> nil, 'Cannot patch nil child');
  MakeAssertion(child <> nil, 'Cannot patch with nil child');

  if parent^.kind = PARSER_PATCHED then
    PatchChild(parent^.child, child)
  else if 
    (parent^.kind = PARSER_RESULT) or
    (parent^.kind = PARSER_KLEENE)
  then
    begin
      MakeAssertion(parent^.child = nil, 'Cannot patch non-nil child');
      
      new_parser := parent^;
      new_parser.child := child;
      new_interned := _internParser(new_parser);

      parent^.kind := PARSER_PATCHED;
      parent^.child := new_interned;
    end
  else
    MakeAssertion(false, 'Invalid parser for patch child');
end;

procedure PatchLeft(parent, child : pParser);
var
  new_parser : rParser;
  new_interned : pParser;
begin
  MakeAssertion(parent <> nil, 'Cannot patch nil child');
  MakeAssertion(child <> nil, 'Cannot patch with nil child');

  if parent^.kind = PARSER_PATCHED then
    PatchLeft(parent^.child, child)
  else if 
    (parent^.kind = PARSER_SEQUENCE) or
    (parent^.kind = PARSER_ALTERNATIVE)
  then
    begin
      MakeAssertion(parent^.left = nil, 'Cannot patch non-nil child');
      new_parser := parent^;
      new_parser.left := child;
      new_interned := _internParser(new_parser);

      parent^.kind := PARSER_PATCHED;
      parent^.child := new_interned;
    end
  else
    MakeAssertion(false, 'Invalid parser for patch left');
end;

procedure PatchRight(parent, child : pParser);
var
  new_parser : rParser;
  new_interned : pParser;
begin
  MakeAssertion(parent <> nil, 'Cannot patch nil child');
  MakeAssertion(child <> nil, 'Cannot patch with nil child');

  if parent^.kind = PARSER_PATCHED then
    PatchRight(parent^.child, child)
  else if 
    (parent^.kind = PARSER_SEQUENCE) or
    (parent^.kind = PARSER_ALTERNATIVE)
  then
    begin
      MakeAssertion(parent^.right = nil, 'Cannot patch non-nil child');
      new_parser := parent^;
      new_parser.right := child;
      new_interned := _internParser(new_parser);

      parent^.kind := PARSER_PATCHED;
      parent^.child := new_interned;
    end
  else
    MakeAssertion(false, 'Invalid parser for patch right');
end;

end.