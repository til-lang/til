release:
	dub build -b release :run --compiler=ldc2
	mv dist/til til.release

debug:
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
