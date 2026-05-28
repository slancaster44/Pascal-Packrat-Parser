program Printer;
uses ParserInterpreter, CursorBuffer;

var
	inp, cmd : rCursorBuffer;
	pi : rParserInterpreter;
	res : pParseResult;
	success : boolean;
begin
	if ParamCount <> 2 then
		begin
			writeln('Usage: ./Printer <pcmd> <input>');
			halt;
		end;

	DiskCursorBuffer(@inp, ParamStr(2), BUFFER_MODE_READ);
	DiskCursorBuffer(@cmd, ParamStr(1), BUFFER_MODE_READ);

	InitParserInterpreter(@pi, @inp, @cmd);
	success := Parse(@pi, @res);

	if success then 
		PrintParseResult(res, 0)
	else
		writeln('Parsing failed');

	CursorBufferClose(@inp);
	CursorBufferClose(@cmd);
end.