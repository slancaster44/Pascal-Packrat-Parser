program Test;
{$define __IMPL__}

{$I inc/VmInterpreter.inc}
{$I inc/Combinator.inc}

var
  f, f1 : TextFile;
  p : array [0..11] of pParser;
  vm : ParseVm;
begin
  p[0] := CharacterParser('c');
  p[1] := CharacterParser('c');
  p[2] := CharacterParser('d');
  Assert(IsParserValid(p[0]), 'Char parser create', 18);
  Assert(p[0] = p[1], 'Char parser intern', 18);
  Assert(p[1] <> p[2], 'Char parser unique', 18);

  p[3] := SequenceParsers(p[0], p[2]);
  p[4] := SequenceParsers(p[0], p[2]);
  p[5] := SequenceParsers(p[0], p[1]);
  Assert(p[3] = p[4], 'Sequence parser intern', 22);
  Assert(p[4] <> p[5], 'Sequence parser unique', 22);

  p[3] := AlternativeParsers(p[0], p[2]);
  p[4] := AlternativeParsers(p[0], p[2]);
  p[5] := AlternativeParsers(p[0], p[1]);
  Assert(p[3] = p[4], 'Alternative parser intern', 25);
  Assert(p[4] <> p[5], 'Alternative parser unique', 25);

  // Kleene parser (regex: "c*"). many_c ::= 'c' | (many_c + 'c')
  p[6] := SequenceParsers(nil, p[0]);
  p[7] := AlternativeParsers(p[0], p[6]);
  p[8] := BackpatchLeft(p[6], p[7]);
  Assert(not IsParserValid(p[6]), 'Parser backpatch remove', 23);
  Assert(IsParserValid(p[8]), 'Parser backpatch insert', 23);
  Assert(p[8]^.left = p[7], 'Parser backpatch, direct replace', 32);
  Assert(p[7]^.right = p[8], 'Parser backpatch, indirect replace', 34);

  //Test right. many_c ::= ('c' + many_c) | 'c'
  p[9] := SequenceParsers(CharacterRangeParser('b', 'c'), nil);
  p[10] := AlternativeParsers(p[9],  CharacterRangeParser('b', 'c'));
  p[11] := BackpatchRight(p[9], p[10]);

  Assert(not IsParserValid(p[9]), 'Parser backpatch remove', 23);
  Assert(IsParserValid(p[11]), 'Parser backpatch insert', 23);
  Assert(p[11]^.right = p[10], 'Parser backpatch, direct replace', 32);
  Assert(p[10]^.left = p[11], 'Parser backpatch, indirect replace', 34);

  FileOpen(@f, 'test.pcmd', FMODE_WRITE);
  CompileParser(@f, p[10]);
  FileClose(@f);

  FileOpen(@f, 'test.txt', FMODE_WRITE);
  FileWrite(@f, 'c');
  FileWrite(@f, 'd');
  FileWrite(@f, 'c');

  FileClose(@f);

  FileOpen(@f, 'test.pcmd', FMODE_READ);
  FileOpen(@f1, 'test.txt', FMODE_READ);
  vm := NewParserVm(@f, @f1);
  Parse(@vm);

  FileClose(@f);
  FileClose(@f1);

  Assert(vm.stateStack[vm.statePointer-1].success, 'vm parse 1 char', 15);
  Assert(vm.stateStack[vm.statePointer-1].start = 0, 'vm parse 1 char, start', 22);
  Assert(vm.stateStack[vm.statePointer-1].stop = 1, 'vm parse 1 char, stop', 21);

  FileOpen(@f, 'test.txt', FMODE_WRITE);
  FileWrite(@f, 'd');
  FileWrite(@f, 'd');
  FileWrite(@f, 'c');

  FileClose(@f);

  FileOpen(@f, 'test.pcmd', FMODE_READ);
  FileOpen(@f1, 'test.txt', FMODE_READ);
  vm := NewParserVm(@f, @f1);
  Parse(@vm);

  FileClose(@f);
  FileClose(@f1);
 
  Assert(not vm.stateStack[vm.statePointer-1].success, 'vm parse no char', 16);
  Assert(vm.stateStack[vm.statePointer-1].start = 0, 'vm parse no char, start', 23);
  Assert(vm.stateStack[vm.statePointer-1].stop = 1, 'vm parse no char, stop', 22);

  FileOpen(@f, 'test.txt', FMODE_WRITE);
  FileWrite(@f, 'c');
  FileClose(@f);

  FileOpen(@f, 'test.pcmd', FMODE_READ);
  FileOpen(@f1, 'test.txt', FMODE_READ);
  vm := NewParserVm(@f, @f1);
  Parse(@vm);

  FileClose(@f);
  FileClose(@f1);
 
  Assert(vm.stateStack[vm.statePointer-1].success, 'vm parse short', 14);
  Assert(vm.stateStack[vm.statePointer-1].start = 0, 'vm parse short, start', 21);
  Assert(vm.stateStack[vm.statePointer-1].stop = 1, 'vm parse short, stop', 20);

  FileOpen(@f, 'test.txt', FMODE_WRITE);
  FileWrite(@f, 'c');
  FileClose(@f);

  FileOpen(@f, 'test.pcmd', FMODE_READ);
  FileOpen(@f1, 'test.txt', FMODE_READ);
  vm := NewParserVm(@f, @f1);
  Parse(@vm);

  FileClose(@f);
  FileClose(@f1);
 
  Assert(vm.stateStack[vm.statePointer-1].success, 'vm parse short', 14);
  Assert(vm.stateStack[vm.statePointer-1].start = 0, 'vm parse short, start', 21);
  Assert(vm.stateStack[vm.statePointer-1].stop = 1, 'vm parse short, stop', 20);

  FileOpen(@f, 'test.txt', FMODE_WRITE);
  FileWrite(@f, 'c');
  FileWrite(@f, 'c');
  FileWrite(@f, 'b');
  FileClose(@f);

  FileOpen(@f, 'test.pcmd', FMODE_READ);
  FileOpen(@f1, 'test.txt', FMODE_READ);
  vm := NewParserVm(@f, @f1);
  Parse(@vm);

  FileClose(@f);
  FileClose(@f1);

  Assert(vm.stateStack[vm.statePointer-1].success, 'vm parse long', 13);
  Assert(vm.stateStack[vm.statePointer-1].start = 0, 'vm parse long, start', 20);
  Assert(vm.stateStack[vm.statePointer-1].stop = 3, 'vm parse long, stop', 19);


  FileOpen(@f, 'test.txt', FMODE_WRITE);
  FileWrite(@f, 'c');
  FileWrite(@f, 'c');
  FileWrite(@f, 'c');
  FileWrite(@f, 'd');
  FileClose(@f);

  FileOpen(@f, 'test.pcmd', FMODE_READ);
  FileOpen(@f1, 'test.txt', FMODE_READ);
  vm := NewParserVm(@f, @f1);
  Parse(@vm);


  Assert(vm.stateStack[vm.statePointer-1].success, 'vm parse long', 13);
  Assert(vm.stateStack[vm.statePointer-1].start = 0, 'vm parse long, start', 20);
  Assert(vm.stateStack[vm.statePointer-1].stop = 3, 'vm parse long, stop', 19);
  Assert(FileGetPosition(vm.inputFile) = 3, 'vm parse long pos', 17);
  Assert(FileRead(vm.inputFile) = 'd', 'vm parse long pos', 17);

  FileClose(@f);
  FileClose(@f1);
end.