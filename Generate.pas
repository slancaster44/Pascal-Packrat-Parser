program Generate;

uses Assertion, CursorBuffer, ParserGenerator;

var
	gram, out, idHdr : rCursorBuffer;
begin
	if ParamCount <> 3 then
		begin
			writeln('Packrat Parser Generator');
			writeln('Usage:');
			writeln('    Generate <grammar_file> <output_parser_file> <output_hdr_file>');
			halt;
		end;

	DiskCursorBuffer(@gram, ParamStr(1), BUFFER_MODE_READ);
	DiskCursorBuffer(@out, ParamStr(2), BUFFER_MODE_WRITE);
	DiskCursorBuffer(@idHdr, ParamStr(3), BUFFER_MODE_WRITE);

	GenerateParser(@gram, @out, @idHdr);

	CursorBufferClose(@idHdr);
	CursorBufferClose(@gram);
	CursorBufferClose(@out);
end.