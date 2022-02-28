module til.modules;

import std.array : split;
import std.file : dirEntries, SpanMode;
import std.path : asAbsolutePath, asNormalizedPath;
import std.process : environment;
import core.sys.posix.dlfcn;
import std.string : strip, toStringz;

import til.nodes;

debug
{
    import std.stdio;
}


string[] modulesPath;


static this()
{
    string home = environment["HOME"];
    string til_path = environment.get(
        "TIL_PATH",
        home ~ "/.til/packages"
    );
    foreach(p; til_path.split(":"))
    {
        modulesPath ~= to!string(asAbsolutePath(
            to!string(asNormalizedPath(p))
        ));
    }
}


bool importModule(Process escopo, string modulePath)
{
    return importModule(escopo, modulePath, modulePath);
}
bool importModule(Process escopo, string modulePath, string prefix)
{
    CommandsMap source;

    try {
        source = importFromSharedLibrary(escopo, modulePath, prefix);
    }
    catch(Exception ex)
    {
        debug {stderr.writeln(ex);}
        return false;
    }

    // Save on cache:
    escopo.importNamesFrom(source, prefix);
    return true;
}

// Import commands from a .so:
CommandsMap importFromSharedLibrary(
    Process escopo, string libraryPath, string moduleAlias
)
{
    // We don't want users informing the library preffix and suffix:
    libraryPath = "libtil_" ~ libraryPath ~ ".so";
    debug {stderr.writeln("libraryPath:", libraryPath);}
    // (Like `libtil_vectors.so`)

    char* lastError;

    foreach(path; modulesPath)
    {
        debug {stderr.writeln("path:",path);}
        // Scan directories recursively searching for a match
        // with libraryPath:
        foreach(dirEntry; path.dirEntries(libraryPath, SpanMode.depth, true))
        {
            debug {stderr.writeln(" dirEntry:", dirEntry);}

            auto libraryPathZ = dirEntry.toStringz;

            // Clean up any old error messages:
            dlerror();

            // lh = "library handler"
            void* lh = dlopen(libraryPathZ, RTLD_LAZY);

            auto error = dlerror();
            if (error !is null)
            {
                lastError = cast(char *)error;
                debug {stderr.writeln(" dlerror: ", lastError);}
                continue;
            }

            // Get the commands from inside the shared object:
            auto getCommands = cast(CommandsMap function(Process))dlsym(
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


void importNamesFrom(
    Process escopo, CommandsMap source, string prefix
)
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
