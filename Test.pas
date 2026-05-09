program UnitTest;

uses Memory, Assertion, CursorBuffer, CharManipulation, 
  ParserCombinators, ParserBytecode, ParserCompiler, ParserInterpreter;

procedure TestAllocator();
var
  alloc : rAllocator;
  p0, p1, p2 : pointer;
begin
  InitAllocator(@alloc);
  DestroyAllocator(@alloc); { TODO: Make better? no assertion to test success }

  InitAllocator(@alloc);
  MakeAssertion(alloc.allocations = nil, 'Allocator init');

  p0 := AllocatorAllocate(@alloc, 32);
  p1 := AllocatorAllocate(@alloc, 32);
  p2 := AllocatorAllocate(@alloc, 32);

  AllocatorFree(@alloc, p1);
  MakeAssertion(alloc.allocations^.memory = p2, 'dealloc middle, 1');
  MakeAssertion(alloc.allocations^.next^.memory = p0, 'dealloc middle, 2');
  MakeAssertion(alloc.allocations^.next^.next = nil, 'dealloc middle, 3');

  DestroyAllocator(@alloc);
  MakeAssertion(alloc.allocations = nil, 'Allocator destroy');

  InitAllocator(@alloc);

  p0 := AllocatorAllocate(@alloc, 32);
  p1 := AllocatorAllocate(@alloc, 32);
  p2 := AllocatorAllocate(@alloc, 32);

  AllocatorFree(@alloc, p0);
  MakeAssertion(alloc.allocations^.memory = p2, 'dealloc tail, 1');
  MakeAssertion(alloc.allocations^.next^.memory = p1, 'dealloc tail, 2');
  MakeAssertion(alloc.allocations^.next^.next = nil, 'dealloc tail, 3');

  DestroyAllocator(@alloc);
  InitAllocator(@alloc);

  p0 := AllocatorAllocate(@alloc, 32);
  p1 := AllocatorAllocate(@alloc, 32);
  p2 := AllocatorAllocate(@alloc, 32);

  AllocatorFree(@alloc, p2);
  MakeAssertion(alloc.allocations^.memory = p1, 'dealloc head, 1');
  MakeAssertion(alloc.allocations^.next^.memory = p0, 'dealloc head, 2');
  MakeAssertion(alloc.allocations^.next^.next = nil, 'dealloc head, 3');

  DestroyAllocator(@alloc);
  InitAllocator(@alloc);

  p0 := AllocatorAllocate(@alloc, 32);
  p1 := AllocatorAllocate(@alloc, 32);
  p2 := AllocatorAllocate(@alloc, 32);

  AllocatorMarkMemory(@alloc, p0);
  AllocatorMarkMemory(@alloc, p2);
  AllocatorFreeUnmarked(@alloc);
  MakeAssertion(alloc.allocations^.memory = p2, 'dealloc middle, 1');
  MakeAssertion(alloc.allocations^.next^.memory = p0, 'dealloc middle, 2');
  MakeAssertion(alloc.allocations^.next^.next = nil, 'dealloc middle, 3');

  DestroyAllocator(@alloc);
  MakeAssertion(alloc.allocations = nil, 'Allocator destroy');

  InitAllocator(@alloc);

  p0 := AllocatorAllocate(@alloc, 32);
  p1 := AllocatorAllocate(@alloc, 32);
  p2 := AllocatorAllocate(@alloc, 32);

  AllocatorMarkMemory(@alloc, p1);
  AllocatorMarkMemory(@alloc, p2);
  AllocatorFreeUnmarked(@alloc);
  MakeAssertion(alloc.allocations^.memory = p2, 'dealloc tail, 1');
  MakeAssertion(alloc.allocations^.next^.memory = p1, 'dealloc tail, 2');
  MakeAssertion(alloc.allocations^.next^.next = nil, 'dealloc tail, 3');

  DestroyAllocator(@alloc);
  InitAllocator(@alloc);

  p0 := AllocatorAllocate(@alloc, 32);
  p1 := AllocatorAllocate(@alloc, 32);
  p2 := AllocatorAllocate(@alloc, 32);

  AllocatorMarkMemory(@alloc, p0);
  AllocatorMarkMemory(@alloc, p1);
  AllocatorFreeUnmarked(@alloc);
  MakeAssertion(alloc.allocations^.memory = p1, 'dealloc head, 1');
  MakeAssertion(alloc.allocations^.next^.memory = p0, 'dealloc head, 2');
  MakeAssertion(alloc.allocations^.next^.next = nil, 'dealloc head, 3');

  DestroyAllocator(@alloc);
end;

procedure TestBufferCursor();
var
  cb : rCursorBuffer;
  mem : array [0..3] of char;
begin
  DiskCursorBuffer(@cb, 'test.txt', BUFFER_MODE_WRITE);
  CursorBufferWrite(@cb, 't');
  CursorBufferWrite(@cb, 'e');
  CursorBufferWrite(@cb, 's');
  CursorBufferWrite(@cb, 't');
  CursorBufferClose(@cb);

  DiskCursorBuffer(@cb, 'test.txt', BUFFER_MODE_READ);
  MakeAssertion(CursorBufferRead(@cb) = 't', 'Readback, disk buffer 1');
  MakeAssertion(CursorBufferRead(@cb) = 'e', 'Readback, disk buffer 2');
  MakeAssertion(CursorBufferRead(@cb) = 's', 'Readback, disk buffer 3');
  MakeAssertion(CursorBufferRead(@cb) = 't', 'Readback, disk buffer 4');

  CursorBufferSeek(@cb, 1);
  MakeAssertion(CursorBufferRead(@cb) = 'e', 'Seek, disk buffer');
  MakeAssertion(CursorBufferPosition(@cb) = 2, 'Position, disk buffer');
  MakeAssertion(CursorBufferLength(@cb) = 4, 'Length, disk buffer');
  MakeAssertion(CursorBufferEnd(@cb) = false, 'Not end, disk buffer');
  CursorBufferSeek(@cb, 4);
  MakeAssertion(CursorBufferEnd(@cb), 'End, disk buffer');

  CursorBufferClose(@cb);

  MemoryCursorBuffer(@cb, mem, 4, BUFFER_MODE_WRITE);
  CursorBufferWrite(@cb, 't');
  CursorBufferWrite(@cb, 'e');
  CursorBufferWrite(@cb, 's');
  CursorBufferWrite(@cb, 't');
  CursorBufferClose(@cb);

  MemoryCursorBuffer(@cb, mem, 4, BUFFER_MODE_READ);
  MakeAssertion(CursorBufferRead(@cb) = 't', 'Readback, mem buffer 1');
  MakeAssertion(CursorBufferRead(@cb) = 'e', 'Readback, mem buffer 2');
  MakeAssertion(CursorBufferRead(@cb) = 's', 'Readback, mem buffer 3');
  MakeAssertion(CursorBufferRead(@cb) = 't', 'Readback, disk buffer 4');

  CursorBufferSeek(@cb, 1);
  MakeAssertion(CursorBufferRead(@cb) = 'e', 'Seek, mem buffer');
  MakeAssertion(CursorBufferPosition(@cb) = 2, 'Position, mem buffer');
  MakeAssertion(CursorBufferLength(@cb) = 4, 'Length, mem buffer');
  MakeAssertion(CursorBufferEnd(@cb) = false, 'Not end, mem buffer');
  CursorBufferSeek(@cb, 4);
  MakeAssertion(CursorBufferEnd(@cb), 'End, mem buffer');
end;

procedure TestCharManip();
begin
  MakeAssertion(GetLo(Combine(char(1), char(2))) = char(2), 'Char manip, get lo');
  MakeAssertion(GetHi(Combine(char(1), char(2))) = char(1), 'Char manip, get hi');
end;

procedure TestCombinators();
var
  p : array [0..11] of pParser;
begin
  p[0] := CharacterParser('c');
  MakeAssertion(GetAllParsers() = p[0], 'get all parsers');
  p[1] := CharacterParser('c');
  p[2] := CharacterParser('d');
  MakeAssertion(IsParserValid(p[0]), 'Char parser create');
  MakeAssertion(p[0] = p[1], 'Char parser intern');
  MakeAssertion(p[1] <> p[2], 'Char parser unique');

  p[3] := SequenceParsers(p[0], p[2]);
  p[4] := SequenceParsers(p[0], p[2]);
  p[5] := SequenceParsers(p[0], p[1]);
  MakeAssertion(p[3] = p[4], 'Sequence parser intern');
  MakeAssertion(p[4] <> p[5], 'Sequence parser unique');

  p[3] := AlternativeParsers(p[0], p[2]);
  p[4] := AlternativeParsers(p[0], p[2]);
  p[5] := AlternativeParsers(p[0], p[1]);
  MakeAssertion(p[3] = p[4], 'Alternative parser intern');
  MakeAssertion(p[4] <> p[5], 'Alternative parser unique');

  // Kleene parser (regex: "c*"). many_c ::= 'c' | (many_c + 'c')
  p[6] := SequenceParsers(nil, p[0]);
  p[7] := AlternativeParsers(p[0], p[6]);
  p[8] := BackpatchLeft(p[6], p[7]);
  MakeAssertion(not IsParserValid(p[6]), 'Parser backpatch remove');
  MakeAssertion(IsParserValid(p[8]), 'Parser backpatch insert');
  MakeAssertion(p[8]^.left = p[7], 'Parser backpatch, direct replace');
  MakeAssertion(p[7]^.right = p[8], 'Parser backpatch, indirect replace');

  //Test right. many_c ::= ('c' + many_c) | 'c'
  p[9] := SequenceParsers(CharacterParser('c'), nil);
  p[10] := AlternativeParsers(p[9],  CharacterRangeParser('b', 'c'));
  p[11] := BackpatchRight(p[9], p[10]);

  MakeAssertion(not IsParserValid(p[9]), 'Parser backpatch remove');
  MakeAssertion(IsParserValid(p[11]), 'Parser backpatch insert');
  MakeAssertion(p[11]^.right = p[10], 'Parser backpatch, direct replace');
  MakeAssertion(p[10]^.left = p[11], 'Parser backpatch, indirect replace');

  ResetParserInternPool();
end;

procedure TestWriteBytecodes();
var
  start_pos, end_pos : cardinal;
  cb : rCursorBuffer;
begin
  DiskCursorBuffer(@cb, 'test.pcmd', BUFFER_MODE_WRITE);

  start_pos := CursorBufferPosition(@cb);
  WriteParseOpRange(@cb, 'a', 'z');
  end_pos := CursorBufferPosition(@cb);
  MakeAssertion((end_pos-start_pos) = ParserInstructionLength(PARSE_OP_RANGE),
    'Unexpected length, range');

  start_pos := CursorBufferPosition(@cb);
  WriteParseOpSequence(@cb, 1, 2);
  end_pos := CursorBufferPosition(@cb);
  MakeAssertion((end_pos-start_pos) = ParserInstructionLength(PARSE_OP_SEQ),
    'Unexpected length, sequence');

  start_pos := CursorBufferPosition(@cb);
  WriteParseOpAlt(@cb, 1, 2);
  end_pos := CursorBufferPosition(@cb);
  MakeAssertion((end_pos-start_pos) = ParserInstructionLength(PARSE_OP_ALT),
    'Unexpected length, sequence');

  start_pos := CursorBufferPosition(@cb);
  WriteParseOpResult(@cb, 1);
  end_pos := CursorBufferPosition(@cb);
  MakeAssertion((end_pos-start_pos) = ParserInstructionLength(PARSE_OP_RES),
    'Unexpected length, sequence');

  CursorBufferClose(@cb);
end;

procedure TestRangeParser();
var
  digit_parser : pParser;
  inp, cmd : rCursorBuffer;
  pi : rParserInterpreter;
  pos0, pos1 : cardinal;
  res : pParseResult;
begin
  digit_parser := CharacterRangeParser('0', '9');

  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_WRITE);
  CompileParser(@cmd, digit_parser);
  CursorBufferClose(@cmd);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_WRITE);
  CursorBufferWrite(@inp, '1'); { Inner character }
  CursorBufferWrite(@inp, '9'); { back edge character }
  CursorBufferWrite(@inp, '0'); { front edge character }
  CursorBufferWrite(@inp, 'a'); { non-matching }
  CursorBufferWrite(@inp, '1'); { character near eof }
  CursorBufferClose(@inp);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_READ);
  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_READ);
  InitParserInterpreter(@pi, @inp, @cmd);

  MakeAssertion(Parse(@pi, @res), 'Character parser, inner character');
  MakeAssertion(Parse(@pi, @res), 'Character parser, back edge');
  MakeAssertion(Parse(@pi, @res), 'Character parser, front edge');
  MakeAssertion(not Parse(@pi, @res), 'Character parser, non-matching');
  CursorBufferRead(@inp); { Skip over failed char }
  MakeAssertion(Parse(@pi, @res), 'Character parser, near eof');

  pos0 := CursorBufferPosition(@inp);
  MakeAssertion(pos0 = CursorBufferLength(@inp), 'Character parser, eof position');
  MakeAssertion(not Parse(@pi, @res), 'Character parser, eof');
  pos1 := CursorBufferPosition(@inp);
  MakeAssertion(pos0 = pos1, 'Character parser, no eof moving');

  CursorBufferClose(@inp);
  CursorBufferClose(@cmd);
end;

procedure TestSequenceParser();
var
  seq_parser : pParser;
  inp, cmd : rCursorBuffer;
  pi : rParserInterpreter;
  res : pParseResult;
begin
  seq_parser := SequenceParsers(CharacterParser('1'),
    CharacterRangeParser('0', '9'));

  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_WRITE);
  CompileParser(@cmd, seq_parser);
  CursorBufferClose(@cmd);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_WRITE);
  CursorBufferWrite(@inp, '1'); { Match }
  CursorBufferWrite(@inp, '9');
  CursorBufferWrite(@inp, '1'); { Non-match back }
  CursorBufferWrite(@inp, 'a');
  CursorBufferWrite(@inp, 'b'); { Non-match front }
  CursorBufferWrite(@inp, '1'); { character near eof }
  CursorBufferClose(@inp);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_READ);
  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_READ);
  InitParserInterpreter(@pi, @inp, @cmd);

  MakeAssertion(Parse(@pi, @res), 'Sequence, match');
  MakeAssertion(CursorBufferPosition(@inp) = 2, 'Sequence, match consumption');
  MakeAssertion(not Parse(@pi, @res), 'Sequence, non-match back');
  CursorBufferRead(@inp);
  MakeAssertion(CursorBufferPosition(@inp) = 3, 'Sequence, non-match consume');
  CursorBufferRead(@inp);
  MakeAssertion(not Parse(@pi, @res), 'Sequence, non-match front');
  MakeAssertion(CursorBufferPosition(@inp) = 4, 'Sequence, non-match consume');
  CursorBufferRead(@inp);
  MakeAssertion(not Parse(@pi, @res), 'Sequence, non-match near eof');
  MakeAssertion(CursorBufferPosition(@inp) = 5, 'Sequence, non-match eof consume');
  CursorBufferRead(@inp);
  MakeAssertion(CursorBufferEnd(@inp), 'Sequence, eof');
  MakeAssertion(not Parse(@pi, @res), 'Sequence, parse after eof');

  CursorBufferClose(@inp);
  CursorBufferClose(@cmd);
end;

procedure TestAlternativeParsers();
var
  alt_parser : pParser;
  inp, cmd : rCursorBuffer;
  pi : rParserInterpreter;
  res : pParseResult;
begin
  alt_parser := AlternativeParsers(CharacterParser('1'),
    CharacterRangeParser('3', '9'));

  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_WRITE);
  CompileParser(@cmd, alt_parser);
  CursorBufferClose(@cmd);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_WRITE);
  CursorBufferWrite(@inp, '1'); { Match left }
  CursorBufferWrite(@inp, '4'); { Match right }
  CursorBufferWrite(@inp, '2'); { Non match }
  CursorBufferClose(@inp);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_READ);
  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_READ);
  InitParserInterpreter(@pi, @inp, @cmd);

  MakeAssertion(Parse(@pi, @res), 'Alternative, match left');
  MakeAssertion(Parse(@pi, @res), 'Alternative, match right');
  MakeAssertion(not Parse(@pi, @res), 'Alternative, non match');
  MakeAssertion(not Parse(@pi, @res), 'Alternative, eof');
  
  CursorBufferClose(@inp);
  CursorBufferClose(@cmd);
end;

procedure TestNonResultParsers();
var
  digit_parser, number_parser : pParser;
  inp, cmd : rCursorBuffer;
  pi : rParserInterpreter;
  res : pParseResult;
begin 
  // number := (('0' - '9') + number) | ('0' - '9') 
  digit_parser := SequenceParsers(CharacterRangeParser('0', '9'), nil);
  number_parser := AlternativeParsers(digit_parser, CharacterRangeParser('0', '9'));
  digit_parser := BackpatchRight(digit_parser, number_parser);

  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_WRITE);
  CompileParser(@cmd, number_parser);
  CursorBufferClose(@cmd);

  { Test, good match }
  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_WRITE);
  CursorBufferWrite(@inp, '1');
  CursorBufferWrite(@inp, '4');
  CursorBufferWrite(@inp, '2'); 
  CursorBufferClose(@inp);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_READ);
  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_READ);
  InitParserInterpreter(@pi, @inp, @cmd);
  
  MakeAssertion(Parse(@pi, @res), 'Nonresult, match');
  MakeAssertion(CursorBufferPosition(@inp) = 3, 'Nonresult match, location');

  CursorBufferClose(@inp);
  CursorBufferClose(@cmd);

  { Test, good match, short }
  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_WRITE);
  CursorBufferWrite(@inp, '1');
  CursorBufferWrite(@inp, '4');
  CursorBufferWrite(@inp, 'a'); 
  CursorBufferClose(@inp);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_READ);
  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_READ);
  InitParserInterpreter(@pi, @inp, @cmd);

  MakeAssertion(Parse(@pi, @res), 'Nonresult, short match');
  MakeAssertion(CursorBufferPosition(@inp) = 2, 'Nonresult short match, location');
  
  CursorBufferClose(@inp);
  CursorBufferClose(@cmd);

  { Test, good match, near eof }
  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_WRITE);
  CursorBufferWrite(@inp, '1');
  CursorBufferClose(@inp);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_READ);
  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_READ);
  InitParserInterpreter(@pi, @inp, @cmd);

  MakeAssertion(Parse(@pi, @res), 'result, short match near eof');
  MakeAssertion(CursorBufferPosition(@inp) = 1, 
    'result short match, location');
  
  CursorBufferClose(@inp);
  CursorBufferClose(@cmd);

  { Test, non match, non near eof }
  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_WRITE);
  CursorBufferWrite(@inp, 'a');
  CursorBufferClose(@inp);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_READ);
  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_READ);
  InitParserInterpreter(@pi, @inp, @cmd);

  MakeAssertion(not Parse(@pi, @res), 'Nonresult, short match near eof');
  MakeAssertion(CursorBufferPosition(@inp) = 0, 
    'Nonresult short match, location');
  
  CursorBufferClose(@inp);
  CursorBufferClose(@cmd);

  { Test, non match, eof }
  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_WRITE);
  CursorBufferClose(@inp);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_READ);
  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_READ);
  InitParserInterpreter(@pi, @inp, @cmd);

  MakeAssertion(not Parse(@pi, @res), 'Nonresult, short match on eof');
  
  CursorBufferClose(@inp);
  CursorBufferClose(@cmd);
end;

procedure TestResultParser();
var
  digit_parser, number_parser, op_parser, expr_parser, final_parser : pParser;
  tmp_parser : pParser;
  inp, cmd : rCursorBuffer;
  pi : rParserInterpreter;
  res : pParseResult;
begin
  digit_parser := SequenceParsers(CharacterRangeParser('0', '9'), nil);
  number_parser := AlternativeParsers(digit_parser, CharacterRangeParser('0', '9'));
  digit_parser := BackpatchRight(digit_parser, number_parser);
  number_parser := ResultGeneratingParser(number_parser);

  op_parser := AlternativeParsers(CharacterParser('+'), CharacterParser('-'));
  op_parser := ResultGeneratingParser(op_parser);
  expr_parser := SequenceParsers(SequenceParsers(number_parser, op_parser), nil);
  tmp_parser := AlternativeParsers(expr_parser, number_parser);

  final_parser := ResultGeneratingParser(tmp_parser);
  expr_parser := BackpatchRight(expr_parser, final_parser);

  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_WRITE);
  CompileParser(@cmd, final_parser);
  CursorBufferClose(@cmd);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_WRITE);
  CursorBufferWrite(@inp, '1'); { Simple number, parsed }
  CursorBufferWrite(@inp, '4');
  CursorBufferWrite(@inp, ' ');
  CursorBufferWrite(@inp, 'a'); { No matching anything }
  CursorBufferWrite(@inp, ' ');
  CursorBufferWrite(@inp, '1'); { Simple expression parsed }
  CursorBufferWrite(@inp, '+');
  CursorBufferWrite(@inp, '2');
  CursorBufferWrite(@inp, ' ');
  CursorBufferWrite(@inp, '1'); { Simple expression failed }
  CursorBufferWrite(@inp, '+'); { Should get just the '1' }
  CursorBufferWrite(@inp, 'a');
  CursorBufferWrite(@inp, ' '); 
  CursorBufferWrite(@inp, '1'); { Complex expression parsed }
  CursorBufferWrite(@inp, '+');
  CursorBufferWrite(@inp, '1');
  CursorBufferWrite(@inp, '-');
  CursorBufferWrite(@inp, '2');
  CursorBufferWrite(@inp, ' ');
  CursorBufferWrite(@inp, '1'); { Complex expression failed }
  CursorBufferWrite(@inp, '+'); { should just get '1 + 1'}
  CursorBufferWrite(@inp, '1');
  CursorBufferWrite(@inp, 'a');
  CursorBufferWrite(@inp, '2');
  CursorBufferClose(@inp);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_READ);
  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_READ);
  InitParserInterpreter(@pi, @inp, @cmd);
  
  MakeAssertion(Parse(@pi, @res), 'Single number, true/false');
  MakeAssertion(res <> nil, 'Single number, result not null');
  MakeAssertion(res^.identifier = final_parser^.identifier, 'Single number, id');
  MakeAssertion(res^.start = 0, 'Single number, start');
  MakeAssertion(res^.stop = 2, 'Single number, stop');
  MakeAssertion(res^.sibling = nil, 'Single number, result sibling');
  MakeAssertion(res^.child <> nil, 'Single number, result child');
  MakeAssertion(res^.child^.child = nil, 'Single number, result 2nd child');
  MakeAssertion(res^.child^.identifier = number_parser^.identifier, 
    'Single number, child ident');
  MakeAssertion(res^.child^.start = 0, 'Single number, child start');
  MakeAssertion(res^.child^.stop = 2, 'Single number, child stop');
  MakeAssertion(res^.child^.sibling = nil, 'Single number, sibling');

  CursorBufferRead(@inp); { Read over space in input }
  res := nil;

  MakeAssertion(not Parse(@pi, @res), 'Single fail, output');
  MakeAssertion(res <> nil, 'Single fail, result not null');
  MakeAssertion(res^.start = 3, 'Single fail, start');
  MakeAssertion(res^.stop = 3, 'Single fail, stop');
  MakeAssertion(res^.child = nil, 'Single fail, child');
  MakeAssertion(res^.sibling = nil, 'Single fail, sibling');

  CursorBufferRead(@inp); { Read over 'a' }
  CursorBufferRead(@inp); { Read over space in input }
  res := nil;

  MakeAssertion(Parse(@pi, @res), 'Simple expr, output');
  MakeAssertion(res <> nil, 'Simple expr, result not nil');
  MakeAssertion(res^.identifier = final_parser^.identifier, 
    'Simple expr, identifier');
  MakeAssertion(res^.start = 5, 'Simple expr, start');
  MakeAssertion(res^.stop = 8, 'Simple expr, stop');
  MakeAssertion(res^.sibling = nil, 'Simple expr, sibling');
  MakeAssertion(res^.child <> nil, 'Simple expr, child');
  MakeAssertion(res^.child^.identifier = number_parser^.identifier, 
    'Simple expr, child identifier');
  MakeAssertion(res^.child^.child = nil, 'Simple expr, 2nd child');
  MakeAssertion(res^.child^.start = 5, 'Simple expr, child start');
  MakeAssertion(res^.child^.stop = 6, 'Simple expr, child stop');
  MakeAssertion(res^.child^.sibling <> nil, 'Simple expr, child sibling');
  MakeAssertion(res^.child^.sibling^.identifier = op_parser^.identifier,
    'Simple expr, child sibling identifier');
  MakeAssertion(res^.child^.sibling^.start = 6, 
    'Simple expr, child sibling start');
  MakeAssertion(res^.child^.sibling^.stop = 7,
    'Simple expr, child sibling stop');
  MakeAssertion(res^.child^.sibling^.sibling <> nil, 
    'Simple expr, 2nd sibling');
  MakeAssertion(
    res^.child^.sibling^.sibling^.identifier = final_parser^.identifier,
    'Simple expr, 2nd sibling identifier');
  MakeAssertion(res^.child^.sibling^.sibling^.start = 7,
    'Simple expr, 2nd sibling start');
  MakeAssertion(res^.child^.sibling^.sibling^.stop = 8,
    'Simple expr, 2nd sibling stop');
  MakeAssertion(
    res^.child^.sibling^.sibling^.child^.identifier = number_parser^.identifier,
    'Simple expr, 2nd child identifier');
  MakeAssertion(res^.child^.sibling^.sibling^.start = 7,
    'Simple expr, 2nd child start');
  MakeAssertion(res^.child^.sibling^.sibling^.stop = 8,
    'Simple expr, 2nd child stop');

  CursorBufferRead(@inp); { Read over space in input }
  res := nil;

  MakeAssertion(Parse(@pi, @res), 'Simple expr, output');
  MakeAssertion(res^.start = 9, 'Simple expr short, start');
  MakeAssertion(res^.stop = 10, 'Simple expr short, stop');
  MakeAssertion(res^.identifier = final_parser^.identifier, 
    'Simple expr short, ident');
  MakeAssertion(res^.child <> nil, 'Simple expr short, child');
  MakeAssertion(res^.child^.start = 9, 'Simple expr short, child start');
  MakeAssertion(res^.child^.stop = 10, 'Simple expr short, child stop');
  MakeAssertion(res^.child^.identifier = number_parser^.identifier,
    'Simple expr short, child ident');

  CursorBufferRead(@inp); 
  CursorBufferRead(@inp); 
  CursorBufferRead(@inp); 
  res := nil;

  MakeAssertion(Parse(@pi, @res), 'Complex expr, output');
  MakeAssertion(res^.identifier = final_parser^.identifier, 'Complex expr, id');
  MakeAssertion(res^.start = 13, 'Complex expr, start');
  MakeAssertion(res^.stop = 18, 'Complex expr, stop');

  PrintParseResult(res, 0);

  CursorBufferRead(@inp); 
  res := nil;

  MakeAssertion(Parse(@pi, @res), 'Complex expr short, output');
  MakeAssertion(res^.identifier = final_parser^.identifier, 
    'Complex expr short, id');
  MakeAssertion(res^.start = 19, 'Complex expr short, start');
  MakeAssertion(res^.stop = 22, 'Complex expr short, stop');

  CursorBufferClose(@inp);
  CursorBufferClose(@cmd);
end;

{ TODO: same tests with memory backed files }

begin
  TestAllocator();
  TestBufferCursor();
  TestCharManip();
  TestWriteBytecodes();
  TestCombinators();
  TestRangeParser();
  TestSequenceParser();
  TestAlternativeParsers();
  TestNonResultParsers();
  TestResultParser();
end.