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

hello.o:
	dmd -c hello.d -fPIC

hello-lib: hello.o
	dmd -oflibhello.so hello.o -shared -defaultlib=libphobos2.so

hellomodule:
	dub build :hellomodule -b release --compiler=ldc2
