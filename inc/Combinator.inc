{$ifndef __COMBINATOR_INC__}
{$define __COMBINATOR_INC__}

{$include inc/File.inc}

type
  ParserKind = (
    PARSER_RANGE, 
    PARSER_SEQUENCE, 
    PARSER_ALTERNATIVE
  );

  Parser = record
    _intern_link : ^Parser;
    _should_compile : boolean;
    _compile_offset : cardinal;

    case kind : ParserKind of
      PARSER_RANGE : (min_char, max_char : char);
      PARSER_SEQUENCE, PARSER_ALTERNATIVE : (left, right : ^Parser);
  end;
  pParser = ^Parser;

function IsParserValid(p : pParser) : boolean; forward;
function CharacterParser(character : char) : pParser; forward;
function SequenceParsers(left, right : pParser) : pParser; forward;
function AlternativeParsers(left, right : pParser) : pParser; forward;
function BackpatchLeft(parent, child: pParser) : pParser; forward;
function BackpatchRight(parent, child: pParser) : pParser; forward;
procedure CompileParser(f : pTextFile; p : pParser); forward;

{$ifdef __IMPL__}
{$include inc/Assert.inc}
{$include inc/Memory.inc}
{$include inc/ByteManip.inc}
{$include inc/VmCommands.inc}

var
  parserInternPool : pParser;

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
      then exit (curParser);
        
      curParser := curParser^._intern_link;
    end;

  curParser := pParser(MemoryAllocate(sizeof(Parser)));
  curParser^ := new_parser;
  curParser^._intern_link := parserInternPool;
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
      if curParser^._intern_link = old_parser then
        curParser^._intern_link := curParser^._intern_link^._intern_link;
      if curParser^.left = old_parser then
        curParser^.left := new_parser;
      if curParser^.right = old_parser then
        curParser^.right := new_parser; 

      curParser := curParser^._intern_link;
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
      curParser := curParser^._intern_link;
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
  Assert(IsParserValid(left) 
    or (left = nil), 'Sequence parser, left not valid', 31);
  Assert(IsParserValid(right)
    or (right = nil), 'Sequence parser, right not valid', 32);

  new_parser.kind := PARSER_SEQUENCE;
  new_parser.left := left;
  new_parser.right := right;
  exit (_internParser(new_parser));
end;

function AlternativeParsers(left, right : pParser) : pParser;
var
  new_parser : Parser;
begin
  Assert(IsParserValid(left)
    or (left = nil), 'Alternative parser, left not valid', 34);
  Assert(IsParserValid(right)
    or (right = nil), 'Alternative parser, right not valid', 35);
  
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
  Assert(parent^.kind <> PARSER_RANGE, 'Cannot backpatch character parser', 33);
  Assert(parent^.left = nil, 'Left child not nil for backpatch', 32);
  Assert(child <> nil, 'New left child nil for backpatch', 32);

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
  Assert(parent^.kind <> PARSER_RANGE, 'Cannot backpatch character parser', 33);
  Assert(parent^.right = nil, 'Right child not nil for backpatch', 32);
  Assert(child <> nil, 'New right child nil for backpatch', 32);

  new_parser := parent^;
  new_parser.right := child;
  new_interned_parser := _internParser(new_parser);
  _replaceParser(parent, new_interned_parser);

  exit(new_interned_parser);
end;

type
  parserHandle = procedure (p : pParser);

procedure _walkAllParsers(handle : parserHandle);
var
  cur : pParser;
begin
  cur := parserInternPool;
  while (cur <> nil) do
    begin
      handle(cur);
      cur := cur^._intern_link;
    end;
end;

procedure _markCompileFalse(p : pParser);
begin
  p^._should_compile := false;
end;

procedure _markShouldCompile(p : pParser);
begin
  Assert(p <> nil, 'Cannot compile "nil" parser', 27);
  p^._should_compile := true;

  if p^.kind = PARSER_RANGE then exit;
  if not (p^.left^._should_compile) then _markShouldCompile(p^.left);
  if not (p^.right^._should_compile) then _markShouldCompile(p^.right);
end;

var
  curCompileOffset : cardinal;
procedure _setCompileOffset(p : pParser);
begin
  if not (p^._should_compile) then exit;
  p^._compile_offset := curCompileOffset;

  if p^.kind = PARSER_RANGE then
    curCompileOffset := curCompileOffset + 4
  else if p^.kind = PARSER_SEQUENCE then
    curCompileOffset := curCompileOffset + 6
  else if p^.kind = PARSER_ALTERNATIVE then
    curCompileOffset := curCompileOffset + 6;
end;

var
  cmdFile : pTextFile;
procedure _writeCommands(p : pParser);
var
  left_lo, left_hi, right_lo, right_hi : char;
begin
  if not (p^._should_compile) then exit;

  FileSeek(cmdFile, p^._compile_offset);
  if p^.kind = PARSER_RANGE then
    begin
      FileWrite(cmdFile, VM_COMMAND_RANGE);
      FileWrite(cmdFile, char(0));
      FileWrite(cmdFile, p^.min_char);
      FileWrite(cmdFile, p^.max_char);
      exit;
    end;
  
  right_hi := GetHi(p^.right^._compile_offset);
  right_lo := GetLo(p^.right^._compile_offset);
  if p^.kind = PARSER_ALTERNATIVE then right_lo := char(cardinal(right_lo) or 1);

  left_hi := GetHi(p^.left^._compile_offset);
  left_lo := GetLo(p^.left^._compile_offset);
  
  FileWrite(cmdFile, left_lo);
  FileWrite(cmdFile, left_hi);
  FileWrite(cmdFile, right_lo);
  FileWrite(cmdFile, right_hi);

  if p^.kind = PARSER_SEQUENCE then
    begin
      FileWrite(cmdFile, VM_COMMAND_RET);
      FileWrite(cmdFile, char(2));
    end
  else if p^.kind = PARSER_ALTERNATIVE then
    begin
      FileWrite(cmdFile, VM_COMMAND_RET);
      FileWrite(cmdFile, char(1));
    end;
end;

procedure CompileParser(f : pTextFile; p : pParser);
var
  entryLow, entryHigh : char;
begin
  { Mark the parsers that actually got used }
  _walkAllParsers(_markCompileFalse);
  _markShouldCompile(p);

  curCompileOffset := 2; { Leave space for header }
  _walkAllParsers(_setCompileOffset);
  Assert(curCompileOffset < ((1 << (CHAR_BITS * 2)) - 1), 'Parser too large', 16);

  { Write in entry address }
  entryLow := GetLo(p^._compile_offset);
  entryHigh := GetHi(p^._compile_offset);
  FileWrite(f, entryLow);
  FileWrite(f, entryHigh);

  cmdFile := f;
  _walkAllParsers(_writeCommands);
end;


{$endif}
{$endif}