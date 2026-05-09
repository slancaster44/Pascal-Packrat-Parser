program Benchmark;

uses CursorBuffer, Assertion,
  ParserCombinators, ParserCompiler, ParserInterpreter;

var
  digit_parser, number_parser, op_parser, expr_parser, final_parser : pParser;
  tmp_parser : pParser;
  inp, cmd : rCursorBuffer;
  pi : rParserInterpreter;
  res : pParseResult;
  i : cardinal;
  curChar : char;
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
  for i := 0 to 100 do
    begin
      curChar := char(ord('0') + ((i << i) mod 9));
      if (i mod 11) = 1 then CursorBufferWrite(@inp, '+');
      CursorBufferWrite(@inp, curChar);
    end;
  CursorBufferClose(@inp);

  DiskCursorBuffer(@inp, 'test.txt', BUFFER_MODE_READ);
  DiskCursorBuffer(@cmd, 'test.pcmd', BUFFER_MODE_READ);
  InitParserInterpreter(@pi, @inp, @cmd);

  MakeAssertion(Parse(@pi, @res), 'Benchmark failed');

  CursorBufferClose(@inp);
  CursorBufferClose(@cmd);
end.