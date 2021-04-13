release:
	ionice -n 7 dub build -b release :run

debug:
	ionice -n 7 dub build -b debug :run

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
