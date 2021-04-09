release:
	dub build -b release

debug:
	dub build -b debug

release-ldc:
	dub build -b release --compiler=ldc2
