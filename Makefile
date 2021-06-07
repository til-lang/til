release:
	dub build -b release :run
	mv dist/til til.release

debug:
	dub build -b debug :run
	mv dist/til til.debug

profile:
	dmd -profile -release \
		source/*/*.d \
		source/*/*/*.d \
		-of=til.profile

libtil_hellomodule.so: modules/hello/hellomodule.d
	dub build :hellomodule -b release

test: libtil_hellomodule.so
	./run-examples.sh
