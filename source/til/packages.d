module til.packages;

import std.array : split;
import std.file : dirEntries, SpanMode;
import std.path : asAbsolutePath, asNormalizedPath, buildPath;
import std.process : environment;
import core.sys.posix.dlfcn;
import std.string : toStringz;

import til.nodes;


/*
*/


bool importModule(Program program, string packageName)
{
    return importFromSharedLibrary(program, packageName);
}

// Import commands from a .so:
bool importFromSharedLibrary(
    Program program, string packageName
)
{
    // We don't want users informing the library preffix and suffix:
    auto libraryPath = "libnow_" ~ packageName ~ ".so";
    debug {stderr.writeln("libraryPath:", libraryPath);}
    // (Like `libnow_vectors.so`)

    char* lastError;

    foreach(path; program.getDependenciesPath())
    {
        debug {stderr.writeln("path:", path);}
        auto packagesPath = asAbsolutePath(
            asNormalizedPath(buildPath(path, "packages")).to!string
        ).to!string;

        debug {stderr.writeln(" packagesPath:", packagesPath);}

        // Scan directories recursively searching for a match
        // with libraryPath:
        foreach(dirEntry; path.dirEntries(libraryPath, SpanMode.shallow, true))
        {
            debug {stderr.writeln(" dirEntry:", dirEntry);}

            // Clean up any old error messages:
            dlerror();

            // lh = "library handler"
            void* lh = dlopen(dirEntry.toStringz, RTLD_LAZY);

            auto error = dlerror();
            if (error !is null)
            {
                lastError = cast(char *)error;
                debug {stderr.writeln(" dlerror: ", to!string(lastError));}
                continue;
            }

            // Get the commands from inside the shared object:
            auto initModule = cast(void function(Program))dlsym(
                lh, "init"
            );

            error = dlerror();
            if (error !is null)
            {
                throw new Exception("dlsym error: " ~ to!string(error));
            }
            initModule(program);
            return true;
        }
    }
    return false;
};
