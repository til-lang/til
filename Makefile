release:
	dub build -b release

debug:
	dub build -b debug

hello.o:
	dmd -c hello.d -fPIC

hello: hello.o
	dmd -oflibhello.so hello.o -shared -defaultlib=libphobos2.so

release-ldc:
	dub build -b release --compiler=ldc2
