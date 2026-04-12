PC=fpc
PCF=-g -MISO

test:
	$(PC) $(PCF) Test.pas
	./Test
	
bench:
	$(PC) $(PCF) Bench.pas
	@start=$$(date +%s%N); \
	./Bench; \
	end=$$(date +%s%N); \
	runtime=$$(echo "scale=9; ($$end - $$start) / 1000000000" | bc -l); \
	echo "Execution Time: $$runtime seconds"

clean:
	rm -f `find . -type f ! -name "*.pas" ! -name "Makefile" ! -name "*.inc" ! -name "TODO" ! -path "./.git/*"`
