release:
	nice -17 dub build -b release
	mv dist/til til.release

debug:
	nice -17 dub build -b debug
	mv dist/til til.debug

profile:
	dmd -profile -release \
		source/*/*.d \
		source/*/*/*.d \
		~/.dub/packages/pegged-0.4.4/pegged/pegged/dynamic/*.d \
		~/.dub/packages/pegged-0.4.4/pegged/pegged/*.d \
		-of=til.profile

hello.o:
	dmd -c hello.d -fPIC

hello-lib: hello.o
	dmd -oflibhello.so hello.o -shared -defaultlib=libphobos2.so

hellomodule.o: hellomodule.o
	dmd -c hellomodule.d -fPIC

hellomodule: hellomodule.o
	dmd -oflibhellomodule.so hellomodule.o -shared -defaultlib=libphobos2.so

release-ldc:
	dub build -b release --compiler=ldc2
	mv dist/til til.ldc2.release
