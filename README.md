Packrat Parser Generate
===

## Build Instructions
```
make generate
```

## Usage

Generate a parser based on a given grammar

#### Create a Grammar File
```
NUMBER = ('0'-'9') + ('0'-'9')*;
TERM = '(' + ADD + ')' / NUMBER;
MUL = TERM + ('*' / '/') + MUL / TERM;
ADD = MUL + ('+' / '-') + ADD / MUL;
EXPR = ADD + ';';
```

#### Generater Parser and Identifier Module
This generates two artifacts. First, a bytecode file containing the parser. Also, a module listing the identifiers for every non-terminal in the generated grammar.

```
./bin/Generate grammar.gram parser.pcmd ParserIdentifiers.pas
```

#### Use the Parser
In a pascal project, you can use the parser like this:

```
program MyProgram;
uses ParserInterpreter, CursorBuffer, ParserIdentifiers;

var
	inp, cmd : rCursorBuffer;
	pi : rParserInterpreter;
	res : pParseResult;
	success : boolean;
begin
	{ See 'MemoryCursorBuffer' if you want to parse in-memory data }
	DiskCursorBuffer(@inp, ParamStr(1), BUFFER_MODE_READ);
	DiskCursorBuffer(@cmd, 'parser.pcmd', BUFFER_MODE_READ);

	InitParserInterpreter(@pi, @inp, @cmd);
	success := Parse(@pi, @res);

	if success then PrintParseResult(res, 0);

	CursorBufferClose(@inp);
	CursorBufferClose(@cmd);
end.
```

Build the program:
```
fpc ./MyProgram.pas -FE./Pascal-Packrat-Parser/bin
```

