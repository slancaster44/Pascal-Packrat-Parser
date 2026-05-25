unit ParserGenerator;
interface
uses CursorBuffer;

procedure GenerateParser(grammar, output : pCursorBuffer);

implementation
uses Assertion, Memory, StrConv,
	ParserCombinators, ParserCompiler, ParserInterpreter;

const
	BOOTSTRAP_PARSER_SIZE = 128;
var
	BootstrapBytecode : array [0..BOOTSTRAP_PARSER_SIZE] of char;
	HEX_CH_ID, LIT_CH_ID : cardinal;
	cmd : rCursorBuffer;

function CombinateGrammarTerm(stmt : pParseResult; gram : pCursorBuffer) : pParser;
var
	startGramPos, readSize : cardinal;
	tmpBuff : pChar;
	result : pParser;
begin
	startGramPos := CursorBufferPosition(gram);
	tmpBuff := nil;
	result := nil;

	if stmt = nil then
		result := nil
	else if stmt^.identifier = HEX_CH_ID then
		begin
			readSize := stmt^.stop - stmt^.start;
			tmpBuff := MemoryAllocate(readSize);
			CursorBufferSeek(gram, stmt^.start);
			CursorBufferReadMultiple(gram, tmpBuff, readSize);
			result := CharacterParser(char(StrToInt(@(tmpBuff[2]), 2, 16)));
		end
	else if stmt^.identifier = LIT_CH_ID then
		begin
			readSize := stmt^.stop - stmt^.start;
			tmpBuff := MemoryAllocate(readSize);
			CursorBufferSeek(gram, stmt^.start);
			CursorBufferReadMultiple(gram, tmpBuff, readSize);
			result := CharacterParser(tmpBuff[1]);
		end
	else
		begin
			write(stmt^.identifier);
			MakeAssertion(false, ' <- Unhandled grammar term');
		end;

	CursorBufferSeek(gram, startGramPos);
	if tmpBuff <> nil then MemoryDeallocate(tmpBuff);
	exit (result);
end;

procedure GenerateParser(grammar, output : pCursorBuffer);
var
	bootstrapInterp : rParserInterpreter;
	res : pParseResult;
	parser : pParser;
begin
	MakeAssertion(grammar^.mode = BUFFER_MODE_READ, 'Non-readable grammar');
	MakeAssertion(output^.mode = BUFFER_MODE_WRITE, 'Non-writable command output');

	MemoryCursorBuffer(@cmd, BootstrapBytecode, BOOTSTRAP_PARSER_SIZE, BUFFER_MODE_READ);
	InitParserInterpreter(@bootstrapInterp, grammar, @cmd);

	parser := nil;
	while (not CursorBufferEnd(grammar)) do
		begin
			MakeAssertion(Parse(@bootstrapInterp, @res), 'Invalid parse grammar');
			parser := CombinateGrammarTerm(res, grammar);
		end;

	if parser <> nil then CompileParser(output, parser);
	CursorBufferClose(@cmd);
end;

var
	hexDigitParser, charParser, parserParser, wsParser : pParser;
initialization
	{ wsParser = \x00 - \x20 }
	wsParser := CharacterRangeParser(char(0), char(32));

	{ hexDigitParser = ('0' - '9') | ('a' - 'f') | 'A' - 'F'}
	hexDigitParser := AlternativeParsers(
		CharacterRangeParser('0', '9'),
		AlternativeParsers(
			CharacterRangeParser('a', 'f'),
			CharacterRangeParser('A', 'F')));

	{ charParser = (''' + (\x00 - \xFF) + ''') | ('\' + 'x' + hexDigitParser + hexDigitParser)}
	charParser := AlternativeParsers(
		{'<char>' form}
		ResultGeneratingParser(
			SequenceParsers(
				CharacterParser(char(39)),
				SequenceParsers(CharacterRangeParser(char(0), char(255)),
					CharacterParser(char(39))))),
		{\x<HEX><HEX> form}
		ResultGeneratingParser(
			SequenceParsers(
				SequenceParsers(
					CharacterParser('\'),
					CharacterParser('x')),
			 	SequenceParsers(
			 		hexDigitParser,
			 		hexDigitParser))));

	parserParser := AlternativeParsers(charParser, wsParser);

	MemoryCursorBuffer(@cmd, BootstrapBytecode, BOOTSTRAP_PARSER_SIZE, BUFFER_MODE_WRITE);
	CompileParser(@cmd, parserParser);

	HEX_CH_ID := charParser^.right^.identifier;
	LIT_CH_ID := charParser^.left^.identifier;

	write('Bootstrap parser size: ');
	writeln(CursorBufferPosition(@cmd));
	CursorBufferClose(@cmd);
	ResetParserInternPool();
end.