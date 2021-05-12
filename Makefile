release:
	nice -17 dub build -b release :run
	mv dist/til til.release

debug:
	nice -17 dub build -b debug :run
	mv dist/til til.debug

profile:
	dmd -profile -release \
		source/*/*.d \
		source/*/*/*.d \
		-of=til.profile

hello.o:
	dmd -c hello.d -fPIC

hello-lib: hello.o
	dmd -oflibhello.so hello.o -shared -defaultlib=libphobos2.so

hellomodule:
	dub build :hellomodule -b release
