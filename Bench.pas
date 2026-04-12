program Benchmark;

{$define __IMPL__}
{$include inc/Combinator.inc}
{$include inc/VmInterpreter.inc}

procedure NumberHandler(state : ParseState);
begin
  writeln(state.success);
  writeln(state.start);
  writeln(state.stop);
end;

var
  digit_parser, number_parser : pParser;
  i : char;
  cmd, inp : TextFile;
  n : cardinal;
  vm : ParseVm;
  text_mem : array [0..121] of char;
  pcmd_mem : array [0..17] of char;
begin

  digit_parser := CharacterRangeParser('0', '9');
  number_parser := SequenceParsers(digit_parser, nil);
  digit_parser := AlternativeParsers(number_parser, digit_parser);
  BackpatchRight(number_parser, digit_parser);

  MemoryFileOpen(@cmd, pcmd_mem, sizeof(pcmd_mem), FMODE_WRITE);
  CompileParser(@cmd, digit_parser);
  FileClose(@cmd);

  DiskFileOpen(@cmd, 'bench.pcmd', FMODE_WRITE);
  CompileParser(@cmd, digit_parser);
  FileClose(@cmd);

  MemoryFileOpen(@inp, text_mem, sizeof(text_mem), FMODE_WRITE);
  for n := 0 to (sizeof(text_mem))-1 do
    begin
      i := char((((n >> 4) xor (n)) mod 10) + ord('0'));
      FileWrite(@inp, i);
    end;
  FileClose(@inp);

  MemoryFileOpen(@cmd, pcmd_mem, 18, FMODE_READ);
  MemoryFileOpen(@inp, text_mem, sizeof(text_mem), FMODE_READ);
  vm := NewParserVm(@cmd, @inp);
  writeln(digit_parser^.handleLocation);
  AddReturnHandler(@vm, digit_parser^.handleLocation, NumberHandler);

  Parse(@vm);
  // for n := 0 to 64 do
  //   begin
  //     Parse(@vm);
  //     FileSeek(@inp, 0);
  //   end;
end.