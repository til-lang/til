module til.packages;

import std.array : split;
import std.file : dirEntries, SpanMode;
import std.path : asAbsolutePath, asNormalizedPath;
import std.process : environment;
import core.sys.posix.dlfcn;
import std.string : toStringz;

import til.nodes;


string[] packagesPaths;


static this()
{
    string home = environment["HOME"];
    string til_path = environment.get(
        "TIL_PATH",
        home ~ "/.til/packages"
    );
    foreach(p; til_path.split(":"))
    {
        packagesPaths ~= to!string(asAbsolutePath(
            to!string(asNormalizedPath(p))
        ));
    }
}


bool importModule(Escopo escopo, string packagePath)
{
    return importModule(escopo, packagePath, packagePath);
}
bool importModule(Escopo escopo, string packagePath, string prefix)
{
    CommandsMap source;

    try {
        source = importFromSharedLibrary(escopo, packagePath, prefix);
    }
    catch(Exception ex)
    {
        // debug {stderr.writeln(ex);}
        return false;
    }

    // Save on cache:
    escopo.importNamesFrom(source, prefix);
    return true;
}

// Import commands from a .so:
CommandsMap importFromSharedLibrary(
    Escopo escopo, string libraryPath, string packageAlias
)
{
    // We don't want users informing the library preffix and suffix:
    libraryPath = "libtil_" ~ libraryPath ~ ".so";
    debug {stderr.writeln("libraryPath:", libraryPath);}
    // (Like `libtil_vectors.so`)

    char* lastError;

    foreach(path; packagesPaths)
    {
        debug {stderr.writeln("path:",path);}
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
            auto getCommands = cast(CommandsMap function(Escopo))dlsym(
                lh, "getCommands"
            );

            error = dlerror();
            if (error !is null)
            {
                throw new Exception("dlsym error: " ~ to!string(error));
            }
            auto libraryCommands = getCommands(escopo);

            return libraryCommands;
        }
    }
    throw new Exception("dlopen error: " ~ to!string(lastError));
};


void importNamesFrom(Escopo escopo, CommandsMap source, string prefix)
{
    foreach(name, command; source)
    {
        string cmdPath;
        if (name is null)
        {
            cmdPath = prefix;
        }
        else
        {
            cmdPath = prefix ~ "." ~ name;
        }
        debug {stderr.writeln("cmdPath:", cmdPath);}
        escopo.commands[cmdPath] = command;
    }
}
