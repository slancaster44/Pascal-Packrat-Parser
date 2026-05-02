

test: str32 assertion memory cursor_buffer char_manip combinator
	fpc ./Test.pas -Fu./bin -FE./bin
	./bin/Test

combinator:
	fpc ./modules/ParserCombinators.pas -Fu./bin -FE./bin

char_manip:
	fpc ./modules/CharManipulation.pas -Fu./bin -FE./bin

cursor_buffer: 
	fpc ./modules/CursorBuffer.pas -Fu./bin -FE./bin

memory: 
	fpc ./modules/Memory.pas -Fu./bin -FE./bin

assertion: 
	fpc ./modules/Assertion.pas -Fu./bin -FE./bin

str32: 
	fpc ./modules/Str32.pas -FE./bin

stroke_ego:
	find . -name "*.pas" | xargs cat | wc -l

clean:
	rm -f `find . -type f ! -name "*.pas" ! -name "Makefile" ! -name "*.inc" ! -name "TODO" ! -path "*.git*"`