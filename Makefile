dist/libtil.so:
	dub build -b release --compiler=ldc2

lib-debug:
	dub build -b debug --compiler=ldc2

release: dist/libtil.so
	dub build -b release :run --compiler=ldc2
	mv dist/til til.release

debug: dist/libtil.so
	dub build -b debug :run --compiler=ldc2
	mv dist/til til.debug

profile:
	dmd -profile -release \
		source/*/*.d \
		source/*/*/*.d \
		-of=til.profile

libtil_hellomodule.so: modules/hello/hellomodule.d
	dub build :hellomodule -b release --compiler=ldc2

test: libtil_hellomodule.so
	./run-examples.sh

clean:
	rm -f til.release
	rm -f til.debug
	rm -f dist/libtil.so
