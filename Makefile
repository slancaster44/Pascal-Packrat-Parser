test: all
	fpc -gl -O- -g ./Test.pas -Fu./bin -FE./bin
	./bin/Test

generate: all
	fpc -gl -O- -g ./Generate.pas -Fu./bin -FE./bin

printer: all
	fpc -gl -O- -g ./Printer.pas -Fu./bin -FE./bin

bench: all
	fpc -gl -O- -g ./Benchmark.pas -Fu./bin -FE./bin
	@start=$$(date +%s%N); \
	./bin/Benchmark; \
	end=$$(date +%s%N); \
	runtime=$$(echo "scale=9; ($$end - $$start) / 1000000000" | bc -l); \
	echo "Execution Time: $$runtime seconds"

all: \
	str32 \
	assertion \
	memory \
	cursor_buffer \
	char_manip \
	combinator \
	bytecode \
	compiler \
	interpreter \
	generator \
	walker

walker:
	fpc -gl -O- -g ./modules/ResultWalker.pas -Fu./bin -FE./bin

generator:
	fpc -gl -O- -g ./modules/ParserGenerator.pas -Fu./bin -FE./bin

interpreter:
	fpc -gl -O- -g ./modules/ParserInterpreter.pas -Fu./bin -FE./bin

compiler:
	fpc -gl -O- -g ./modules/ParserCompiler.pas -Fu./bin -FE./bin

bytecode:
	fpc -gl -O- -g ./modules/ParserBytecode.pas -Fu./bin -FE./bin

combinator:
	fpc -gl -O- -g ./modules/ParserCombinators.pas -Fu./bin -FE./bin

char_manip:
	fpc -gl -O- -g ./modules/CharManipulation.pas -Fu./bin -FE./bin

cursor_buffer: 
	fpc -gl -O- -g ./modules/CursorBuffer.pas -Fu./bin -FE./bin

memory: 
	fpc -gl -O- -g ./modules/Memory.pas -Fu./bin -FE./bin

assertion: 
	fpc -gl -O- -g ./modules/Assertion.pas -Fu./bin -FE./bin

str32: 
	fpc -gl -O- -g ./modules/Str32.pas -FE./bin

stroke_ego:
	find . -name "*.pas" | xargs cat | wc -l

clean:
	rm -f `find . -type f \
		! -name "*.pas" \
		! -path "*.md" \
		! -name "Makefile" \
		! -name "*.inc" \
		! -name "TODO" \
		! -path "*.git*"`