

test: all
	fpc -g ./Test.pas -Fu./bin -FE./bin
	./bin/Test

all: str32 assertion memory cursor_buffer char_manip combinator bytecode compiler

compiler:
	fpc -g ./modules/ParserCompiler.pas -Fu./bin -FE./bin

bytecode:
	fpc -g ./modules/ParserBytecode.pas -Fu./bin -FE./bin

combinator:
	fpc -g ./modules/ParserCombinators.pas -Fu./bin -FE./bin

char_manip:
	fpc -g ./modules/CharManipulation.pas -Fu./bin -FE./bin

cursor_buffer: 
	fpc -g ./modules/CursorBuffer.pas -Fu./bin -FE./bin

memory: 
	fpc -g ./modules/Memory.pas -Fu./bin -FE./bin

assertion: 
	fpc -g ./modules/Assertion.pas -Fu./bin -FE./bin

str32: 
	fpc -g ./modules/Str32.pas -FE./bin

stroke_ego:
	find . -name "*.pas" | xargs cat | wc -l

clean:
	rm -f `find . -type f ! -name "*.pas" ! -name "Makefile" ! -name "*.inc" ! -name "TODO" ! -path "*.git*"`