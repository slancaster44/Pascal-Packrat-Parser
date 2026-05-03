program UnitTest;

uses Memory, Assertion, CursorBuffer, CharManipulation, 
  ParserCombinators, ParserBytecode, ParserCompiler, ParserInterpreter;

procedure TestAllocator();
var
  alloc : rAllocator;
  p0, p1, p2 : pointer;
begin
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

  ParserMarkAllChildrenOf(p[10]);
  MakeAssertion(p[10]^.mark = true, 'Parser mark, parent');
  MakeAssertion(p[11]^.mark = true, 'Parser mark, child');
  MakeAssertion(p[8]^.mark = false, 'Parser mark, non-child');

  ParserUnmarkAll();
  MakeAssertion(p[10]^.mark = false, 'Parser unmark, parent');
  MakeAssertion(p[11]^.mark = false, 'Parser unmark, child');
  MakeAssertion(p[8]^.mark = false, 'Parser unmark, non-child');

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
  MakeAssertion(Parse(@pi), 'Character parser, inner character');
  MakeAssertion(Parse(@pi), 'Character parser, back edge');
  MakeAssertion(Parse(@pi), 'Character parser, front edge');
  MakeAssertion(not Parse(@pi), 'Character parser, non-matching');
  MakeAssertion(Parse(@pi), 'Character parser, near eof');

  pos0 := CursorBufferPosition(@inp);
  MakeAssertion(pos0 = CursorBufferLength(@inp), 'Character parser, eof position');
  MakeAssertion(not Parse(@pi), 'Character parser, eof');
  pos1 := CursorBufferPosition(@inp);
  MakeAssertion(pos0 = pos1, 'Character parser, no eof moving');

  CursorBufferClose(@inp);
  CursorBufferClose(@cmd);
end;

procedure TestSequenceParser();
begin

end;

begin
  TestAllocator();
  TestBufferCursor();
  TestCharManip();
  TestWriteBytecodes();
  TestCombinators();
  TestRangeParser();
  TestSequenceParser();
end.