release:
	ionice -n 7 dub build -b release :run
	mv til_run til.release

debug:
	ionice -n 7 nice -+18 dub build -b debug :run
	mv til_run til.debug

profile:
	dub build -b profile --force :profile

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
