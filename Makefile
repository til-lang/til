release:
	dub build -b release

release-ldc:
	dub build -b release --compiler=ldc2
