

test: all
	fpc -O- -g ./Test.pas -Fu./bin -FE./bin
	./bin/Test

bench: all
	fpc -O- -g ./Benchmark.pas -Fu./bin -FE./bin
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
	interpreter

interpreter:
	fpc -O- -g ./modules/ParserInterpreter.pas -Fu./bin -FE./bin

compiler:
	fpc -O- -g ./modules/ParserCompiler.pas -Fu./bin -FE./bin

bytecode:
	fpc -O- -g ./modules/ParserBytecode.pas -Fu./bin -FE./bin

combinator:
	fpc -O- -g ./modules/ParserCombinators.pas -Fu./bin -FE./bin

char_manip:
	fpc -O- -g ./modules/CharManipulation.pas -Fu./bin -FE./bin

cursor_buffer: 
	fpc -O- -g ./modules/CursorBuffer.pas -Fu./bin -FE./bin

memory: 
	fpc -O- -g ./modules/Memory.pas -Fu./bin -FE./bin

assertion: 
	fpc -O- -g ./modules/Assertion.pas -Fu./bin -FE./bin

str32: 
	fpc -O- -g ./modules/Str32.pas -FE./bin

stroke_ego:
	find . -name "*.pas" | xargs cat | wc -l

clean:
	rm -f `find . -type f ! -name "*.pas" ! -name "Makefile" ! -name "*.inc" ! -name "TODO" ! -path "*.git*"`