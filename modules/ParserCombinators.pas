unit ParserCombinators;
interface

type
  ParserKind = (
    PARSER_RANGE,         { Tests if a character is in a given range } 
    PARSER_SEQUENCE,      { Tests if two sub-parsers pass }
    PARSER_ALTERNATIVE,   { Returns the state of the first sub-parser to pass }
    PARSER_RESULT         { Generates a result, given the current state }
  );

  Parser = record
    next : ^Parser;
    mark : boolean;

    case kind : ParserKind of
      PARSER_RANGE : (min_char, max_char : char);
      PARSER_SEQUENCE, PARSER_ALTERNATIVE : (left, right : ^Parser);
      PARSER_RESULT : (child : ^Parser);
  end;
  pParser = ^Parser;

function IsParserValid(p : pParser) : boolean;
function CharacterParser(character : char) : pParser;
function CharacterRangeParser(min, max : char) : pParser;
function SequenceParsers(left, right : pParser) : pParser;
function AlternativeParsers(left, right : pParser) : pParser;
function ResultGeneratingParser(child : pParser) : pParser;
function BackpatchLeft(parent, child: pParser) : pParser;
function BackpatchRight(parent, child: pParser) : pParser;
function GetAllParsers() : pParser;
procedure ParserMarkAllChildrenOf(p : pParser);

implementation uses Assertion, Memory;

var
  parserInternPool : pParser;

function GetAllParsers() : pParser;
begin
  exit (parserInternPool);
end;

function _internParser(new_parser : Parser) : pParser;
var
  curParser : pParser;

  function BothAre(kind : ParserKind) : boolean;
  begin
    exit ((new_parser.kind = kind) and (curParser^.kind = kind));
  end;

  function ChildrenMatch() : boolean;
  begin { 'nil' indicates a child parser that will be added later }
    exit (((new_parser.left <> nil) and (curParser^.left <> nil)) and
      ((new_parser.right <> nil) and (curParser^.right <> nil)) and
      (new_parser.right = curParser^.right) and 
      (new_parser.left = curParser^.left));
  end;
begin
  curParser := parserInternPool;

  while (curParser <> nil) do
    begin
      if
        (BothAre(PARSER_RANGE) and
          ((curParser^.min_char) = (new_parser.min_char)) and
          ((curParser^.max_char) = (new_parser.max_char)))
        or
          (BothAre(PARSER_ALTERNATIVE) and ChildrenMatch())
        or
          (BothAre(PARSER_SEQUENCE) and ChildrenMatch())
        or
          ((BothAre(PARSER_RESULT)) and
            (curParser^.child = new_parser.child))
      then exit (curParser);
        
      curParser := curParser^.next;
    end;

  curParser := pParser(MemoryAllocate(sizeof(Parser)));
  curParser^ := new_parser;
  curParser^.next := parserInternPool;
  curParser^.mark := false;
  parserInternPool := curParser;
  exit (curParser);
end;

procedure _replaceParser(old_parser, new_parser : pParser);
var
  curParser : pParser;
begin
  curParser := parserInternPool;

  while (curParser <> nil) do
    begin
      if curParser^.next = old_parser then
        curParser^.next := curParser^.next^.next;
      if curParser^.left = old_parser then
        curParser^.left := new_parser;
      if curParser^.right = old_parser then
        curParser^.right := new_parser; 

      curParser := curParser^.next;
    end;
  
  FreeMem(old_parser);
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
  new_parser : Parser;
begin
  new_parser.kind := PARSER_RANGE;
  new_parser.min_char := character;
  new_parser.max_char := character;
  exit (_internParser(new_parser));
end;

function CharacterRangeParser(min, max : char) : pParser;
var
  new_parser : Parser;
begin
  new_parser.kind := PARSER_RANGE;
  new_parser.min_char := min;
  new_parser.max_char := max;
  exit (_internParser(new_parser));
end;

function SequenceParsers(left, right : pParser) : pParser;
var
  new_parser : Parser;
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

function ResultGeneratingParser(child : pParser) : pParser;
var
  new_parser : Parser;
begin
  MakeAssertion(child <> nil, 'Child parser cannot be nil');
  MakeAssertion(IsParserValid(child), 'Child must be valid parser');

  new_parser.kind := PARSER_RESULT;
  new_parser.child := child;
  exit (_internParser(new_parser));
end;

function AlternativeParsers(left, right : pParser) : pParser;
var
  new_parser : Parser;
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

function BackpatchLeft(parent, child: pParser) : pParser;
var
  new_parser : Parser;
  new_interned_parser : pParser;
begin
  MakeAssertion(child <> nil, 'New left child nil for backpatch');
  MakeAssertion(IsParserValid(child), 'Cannot backpatch with invalid parser');
  MakeAssertion((parent^.kind = PARSER_ALTERNATIVE) or
    (parent^.kind = PARSER_SEQUENCE), 'Cannot backpatch parser');
  MakeAssertion(parent^.left = nil, 'Left child not nil for backpatch');

  new_parser := parent^;
  new_parser.left := child;
  new_interned_parser := _internParser(new_parser);
  _replaceParser(parent, new_interned_parser);

  exit (new_interned_parser);
end;

function BackpatchRight(parent, child: pParser) : pParser;
var
  new_parser : Parser;
  new_interned_parser : pParser;
begin
  MakeAssertion(child <> nil, 'New right child nil for backpatch');
  MakeAssertion(IsParserValid(child), 'Cannot backpatch with invalid parser');
  MakeAssertion((parent^.kind = PARSER_ALTERNATIVE) or
    (parent^.kind = PARSER_SEQUENCE), 'Cannot backpatch parser');
  MakeAssertion(parent^.right = nil, 'Right child not nil for backpatch');

  new_parser := parent^;
  new_parser.right := child;
  new_interned_parser := _internParser(new_parser);
  _replaceParser(parent, new_interned_parser);

  exit(new_interned_parser);
end;

procedure ParserMarkAllChildrenOf(p : pParser);
begin
  if p^.mark then
    exit;

  p^.mark := true;

  if (p^.kind = PARSER_RANGE) or (p^.kind = PARSER_SEQUENCE) then  
    begin
      ParserMarkAllChildrenOf(p^.left);
      ParserMarkAllChildrenOf(p^.right);
    end
  else if (p^.kind = PARSER_RESULT) then
    begin
      ParserMarkAllChildrenOf(p^.child)
    end;
end;

end.