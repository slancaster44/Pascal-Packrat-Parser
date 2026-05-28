unit ParserGenerator;
interface
uses CursorBuffer;

procedure GenerateParser(grammar, output, idHdr : pCursorBuffer);

implementation
uses Assertion, Memory, StrConv, Str32,
	ParserCombinators, ParserCompiler, ParserInterpreter;

type
	ePatchKind = (PATCH_LEFT, PATCH_RIGHT, PATCH_CHILD, PATCH_ERROR);

	rPatch = record
		next : ^rPatch;
		kind : ePatchKind;
		patchee : pParser;
	end;
	pPatch = ^rPatch;

	rIdentifier = record
		next : ^rIdentifier;
		sigName : acRawStr;
		boundParser : pParser;
		patches : pPatch;
	end;
	pIdentifier = ^rIdentifier;

const
	BOOTSTRAP_PARSER_SIZE = 300;
var
	BootstrapBytecode : array [0..BOOTSTRAP_PARSER_SIZE] of char;
	HEX_CH_ID, LIT_CH_ID, RANGE_CH_ID, POST_ID : cardinal;
	SEQ_ID, ALT_ID, IDENT_ID, ASSGN_ID : cardinal;
	cmd : rCursorBuffer;
	idents : pIdentifier;

procedure ResetIdentifiers();
var
	toFree : pIdentifier;
begin
	while idents <> nil do
		begin
			toFree := idents;
			idents := idents^.next;
			MemoryDeallocate(toFree);
		end;
end;

procedure ApplyPatches(patch : pPatch; new_child : pParser);
begin
	if patch = nil then exit;

	if (patch^.kind = PATCH_LEFT) then
		PatchLeft(patch^.patchee, new_child)
	else if (patch^.kind = PATCH_RIGHT) then
		PatchRight(patch^.patchee, new_child)
	else if (patch^.kind = PATCH_CHILD) then
		PatchChild(patch^.patchee, new_child)
	else
		MakeAssertion(false, 'Unknown patch type');

	ApplyPatches(patch^.next, new_child);
	MemoryDeallocate(patch);
end;

function GetIdentifier(fullName : pChar; fullLen : cardinal) : pIdentifier;
var
	sigName : acRawStr;
	curIdent : pIdentifier;
begin
	sigName := FreeStrToRawStr(fullName, fullLen);

	curIdent := idents;
	while curIdent <> nil do
		begin
			if curIdent^.sigName = sigName then exit(curIdent);
			curIdent := curIdent^.next;
		end;

	curIdent := MemoryAllocate(sizeof(rIdentifier));
	curIdent^.next := idents;
	curIdent^.sigName := sigName;
	curIdent^.boundParser := nil;
	curIdent^.patches := nil;

	idents := curIdent;
	exit (curIdent);
end;

procedure PrintIdent(cb : pCursorBuffer; id : pIdentifier);
var
	d, i : cardinal;
	buf : acRawStr;
begin
	if id = nil then exit;
	CursorBufferWriteMultiple(cb, '    PARSE_ID_');
	CursorBufferWriteMultiple(cb, id^.sigName);
	CursorBufferWriteMultiple(cb, ' = ');

	d := id^.boundParser^.identifier;
	if d = 0 then 
		CursorBufferWrite(cb, '0')
	else
		begin
			i := sizeof(acRawStr)-1;
			while d > 0 do
				begin
					writeln(i);
					buf[i] := char(cardinal('0') + (d mod 10));
					d := d div 10;
					i := i-1;
				end;

			for d := 0 to (sizeof(acRawStr)-i)-1 do
				begin
					CursorBufferWrite(cb, buf[i+d]);
				end;
		end;

	CursorBufferWriteMultiple(cb, ';');
	CursorBufferWrite(cb, char(10));
	PrintIdent(cb, id^.next);
end;

procedure PrintIdents(cb : pCursorBuffer);
begin
	CursorBufferWriteMultiple(cb, 'unit ParserIdentifiers;');
	CursorBufferWrite(cb, char(10));
	CursorBufferWriteMultiple(cb, 'interface');
	CursorBufferWrite(cb, char(10));
	CursorBufferWriteMultiple(cb, 'const');
	CursorBufferWrite(cb, char(10));
	PrintIdent(cb, idents);
	CursorBufferWriteMultiple(cb, 'implementation');
	CursorBufferWrite(cb, char(10));
	CursorBufferWriteMultiple(cb, 'end.');
	CursorBufferWrite(cb, char(10));
end;

function CombinateGrammarTerm(stmt : pParseResult; 
		gram : pCursorBuffer; 
		parent : pParser; 
		pkind : ePatchKind) : pParser;
var
	startGramPos, readSize : cardinal;
	tmpBuff : pChar;
	left, right, result : pParser;
	id : pIdentifier;
	patch : pPatch;
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
	else if stmt^.identifier = IDENT_ID then
		begin
			readSize := stmt^.stop - stmt^.start;
			tmpBuff := MemoryAllocate(readSize);
			CursorBufferSeek(gram, stmt^.start);
			CursorBufferReadMultiple(gram, tmpBuff, readSize);
			id := GetIdentifier(tmpBuff, readSize);
			if id^.boundParser = nil then
				begin
					patch := MemoryAllocate(sizeof(rPatch));
					patch^.next := id^.patches;
					patch^.patchee := parent;
					patch^.kind := pkind;
					id^.patches := patch;
				end;

			result := id^.boundParser;
		end
	else if stmt^.identifier = POST_ID then
		begin
			result := KleeneParser(nil);
			left := CombinateGrammarTerm(stmt^.child, gram, result, PATCH_CHILD);
			if left <> nil then PatchChild(result, left);
		end
	else if stmt^.identifier = RANGE_CH_ID then
		begin
			MakeAssertion(stmt^.child <> nil, 'Range parser, child');
			MakeAssertion(stmt^.child^.sibling <> nil, 'Range parser sibling');
			left := CombinateGrammarTerm(stmt^.child, gram, nil, PATCH_ERROR);
			right := CombinateGrammarTerm(stmt^.child^.sibling, gram, nil, PATCH_ERROR);
			result := CharacterRangeParser(left^.match_char, right^.match_char);
		end
	else if stmt^.identifier = SEQ_ID then
		begin
			MakeAssertion(stmt^.child <> nil, 'SequenceParsers parser, child');
			MakeAssertion(stmt^.child^.sibling <> nil, 'SequenceParsers parser sibling');
			result := SequenceParsers(nil, nil);
			left := CombinateGrammarTerm(stmt^.child, gram, result, PATCH_LEFT);
			right := CombinateGrammarTerm(stmt^.child^.sibling, gram, result, PATCH_RIGHT);
			if left <> nil then PatchLeft(result, left);
			if right <> nil then PatchRight(result, right)
		end
	else if stmt^.identifier = ALT_ID then
		begin
			MakeAssertion(stmt^.child <> nil, 'Alternative parser, child');
			MakeAssertion(stmt^.child^.sibling <> nil, 'Alternative parser sibling');
			result := AlternativeParsers(nil, nil);
			left := CombinateGrammarTerm(stmt^.child, gram, result, PATCH_LEFT);
			right := CombinateGrammarTerm(stmt^.child^.sibling, gram, result, PATCH_RIGHT);
			if left <> nil then PatchLeft(result, left);
			if right <> nil then PatchRight(result, right);
		end
	else if stmt^.identifier = ASSGN_ID then
		begin
			readSize := stmt^.child^.stop - stmt^.child^.start;
			tmpBuff := MemoryAllocate(readSize);
			CursorBufferSeek(gram, stmt^.child^.start);
			CursorBufferReadMultiple(gram, tmpBuff, readSize);

			result := ResultGeneratingParser(nil);
			right := CombinateGrammarTerm(stmt^.child^.sibling, gram, result, PATCH_CHILD);
			id := GetIdentifier(tmpBuff, readSize);
			id^.boundParser := result;
		 	if right <> nil then PatchChild(result, right); 
			ApplyPatches(id^.patches, result);
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

procedure GenerateParser(grammar, output, idHdr : pCursorBuffer);
var
	bootstrapInterp : rParserInterpreter;
	res : pParseResult;
	parser : pParser;
begin
	MakeAssertion(grammar^.mode = BUFFER_MODE_READ, 'Non-readable grammar');
	MakeAssertion(output^.mode = BUFFER_MODE_WRITE, 'Non-writable command output');

	MemoryCursorBuffer(@cmd, BootstrapBytecode, BOOTSTRAP_PARSER_SIZE, BUFFER_MODE_READ);
	InitParserInterpreter(@bootstrapInterp, grammar, @cmd);
	ResetIdentifiers();

	parser := nil;
	while (not CursorBufferEnd(grammar)) do
		begin
			MakeAssertion(Parse(@bootstrapInterp, @res), 'Grammar syntax error');
			parser := CombinateGrammarTerm(res, grammar,nil, PATCH_ERROR);
		end;

	if parser <> nil then CompileParser(output, parser);
	PrintIdents(idHdr);
	CursorBufferClose(@cmd);
end;

var
	hexDigitParser, hexChParser, quoteChParser : pParser;
	charParser, parserParser, wsParser : pParser;
	rangeParser, groupPred, groupParser, termParser : pParser;
	postfixParser, postfixOrTermP, seqParser, exprParser : pParser;
	seqOrPostfixP, altParser, altOrSeqP, identifierP : pParser;
 	assignP, assignOrExprP, stmtP : pParser;
initialization
	{ wsParser = \x00 - \x20 }
	wsParser := KleeneParser(CharacterRangeParser(char(0), char(32)));

	{ hexDigitParser = ('0' - '9') | ('a' - 'f') | 'A' - 'F' }
	hexDigitParser := AlternativeParsers(
		CharacterRangeParser('0', '9'),
		AlternativeParsers(
			CharacterRangeParser('a', 'f'),
			CharacterRangeParser('A', 'F')));

	{ hexChParser = '\' + 'x' + hexDigitParser + hexDigitParser}
	hexChParser := ResultGeneratingParser(
		SequenceParsers(
			SequenceParsers(
				CharacterParser('\'),
				CharacterParser('x')),
		 	SequenceParsers(
		 		hexDigitParser,
		 		hexDigitParser)));

	{ quoteChParser = ''' + (\x00 - \xFF) + ''' }
	quoteChParser := ResultGeneratingParser(
		SequenceParsers(
			CharacterParser(char(39)),
			SequenceParsers(
				CharacterRangeParser(char(0), char(255)),
				CharacterParser(char(39)))));

	{ identifierP = ((a-z) | (A-Z) | '_') + (((a-z) | (A-Z) | '_')*) }
	identifierP := ResultGeneratingParser(
		SequenceParsers(	
			AlternativeParsers(
				AlternativeParsers(
					CharacterRangeParser('a', 'z'),
					CharacterRangeParser('A', 'Z')),
				CharacterParser('_')),
			KleeneParser(
				AlternativeParsers(
					AlternativeParsers(
						CharacterRangeParser('a', 'z'),
						CharacterRangeParser('A', 'Z')),
					CharacterParser('_')))));

	{ charParser = quoteChParser | hexChParser }
	charParser := AlternativeParsers(
		quoteChParser,
		hexChParser);

	{ rangeParser = charParser + wsParser + '-' + wsParser + charParser }
	rangeParser := ResultGeneratingParser(
		SequenceParsers(
			SequenceParsers(
				SequenceParsers(charParser, wsParser),
				SequenceParsers(CharacterParser('-'), wsParser)),
			charParser));

	{ groupParser = '(' + expr + ')' }
	groupPred := SequenceParsers(CharacterParser('('), nil);
	groupParser := SequenceParsers(
		groupPred,
		SequenceParsers(
			wsParser,
			CharacterParser(')')));

	{ termParser = wsParser + (rangeParser | charParser) }
	termParser := SequenceParsers(wsParser,
		AlternativeParsers(
			AlternativeParsers(rangeParser, charParser),
			AlternativeParsers(identifierP, groupParser)));

	{ postfixParser = termParser * }
	postfixParser := ResultGeneratingParser(
		SequenceParsers(
			termParser,
			SequenceParsers(
				wsParser,
				CharacterParser('*'))));
	postfixOrTermP := AlternativeParsers(postfixParser, termParser);

	{ seqParser = postfixOrTermP + wsParser + '+' + postfixOrTermP }
	seqParser := ResultGeneratingParser(
		SequenceParsers(
			SequenceParsers(
				postfixOrTermP,
				SequenceParsers(
					wsParser, 
					CharacterParser('+'))),
			nil));
	seqOrPostfixP := AlternativeParsers(seqParser, postfixOrTermP);
	PatchRight(seqParser^.child, seqOrPostfixP);

	{ altParser = seqOrPostfixP + wsParser + '/' + seqOrPostfixP }
	altParser := ResultGeneratingParser(
		SequenceParsers(
			SequenceParsers(
				seqOrPostfixP,
				SequenceParsers(
					wsParser, 
					CharacterParser('/'))),
			nil));
	altOrSeqP := AlternativeParsers(altParser, seqOrPostfixP);
	PatchRight(altParser^.child, altOrSeqP);

	exprParser := altOrSeqP;
	PatchRight(groupPred, exprParser);

	{ assignP = identifierP + wsParser + '=' + exprParser }
	assignP := ResultGeneratingParser(
		SequenceParsers(
			SequenceParsers(
				identifierP, 
				wsParser),
			SequenceParsers(
				CharacterParser('='), 
				exprParser)));
	assignOrExprP := AlternativeParsers(assignP, exprParser);

	stmtP := SequenceParsers(
		assignOrExprP, 
		SequenceParsers(
			wsParser, 
			CharacterParser(';')));

	parserParser := AlternativeParsers(stmtP, wsParser);

	MemoryCursorBuffer(@cmd, BootstrapBytecode, BOOTSTRAP_PARSER_SIZE, BUFFER_MODE_WRITE);
	CompileParser(@cmd, parserParser);

	HEX_CH_ID := hexChParser^.identifier;
	LIT_CH_ID := quoteChParser^.identifier;
	RANGE_CH_ID := rangeParser^.identifier;
	IDENT_ID := identifierP^.identifier;
	POST_ID := postfixParser^.identifier;
	SEQ_ID := seqParser^.identifier;
	ALT_ID := altParser^.identifier;
	ASSGN_ID := assignP^.identifier;

	// write('Bootstrap parser size: ');
	// writeln(CursorBufferPosition(@cmd));

	// write('HEX_CH_ID: ');
	// writeln(HEX_CH_ID);
	// write('LIT_CH_ID: ');
	// writeln(LIT_CH_ID);
	// write('RANGE_CH_ID: ');
	// writeln(RANGE_CH_ID);
	// write('IDENT_ID: ');
	// writeln(IDENT_ID);
	// write('POST_ID: ');
	// writeln(POST_ID);
	// write('SEQ_ID: ');
	// writeln(SEQ_ID);
	// write('ALT_ID: ');
	// writeln(ALT_ID);
	// write('ASSGN_ID: ');
	// writeln(ASSGN_ID);

	CursorBufferClose(@cmd);
	ResetParserInternPool();
end.