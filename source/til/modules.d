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


CommandHandler[string][string] sourcesCache;
string[] modulesPath;


static this()
{
    string home = environment["HOME"];
    string til_path = environment.get(
        "TIL_PATH",
        home ~ "/.dub/packages"
    );
    foreach(p; til_path.split(":"))
    {
        modulesPath ~= to!string(asAbsolutePath(
            to!string(asNormalizedPath(p))
        ));
    }
}


bool importModule(SubProgram program, string modulePath)
{
    return importModule(program, modulePath, modulePath);
}
bool importModule(SubProgram program, string modulePath, string prefix)
{
    CommandHandler[string] source;

    // 0- cache:
    auto cachedSource = (modulePath in sourcesCache);
    if (cachedSource !is null)
    {
        program.importNamesFrom(*cachedSource, prefix);
        return true;
    }

    // 1- builtin modules:
    source = program.availableModules.get(modulePath, null);

    // 2- from shared libraries:
    if (source is null)
    {
        return false;
    }

    // Save on cache:
    program.importNamesFrom(source, prefix);
    sourcesCache[modulePath] = source;
    return true;
}

bool importModuleFromSharedLibrary(SubProgram program, string modulePath)
{
    return importModuleFromSharedLibrary(program, modulePath, modulePath);
}
bool importModuleFromSharedLibrary(
    SubProgram program, string modulePath, string prefix
)
{
    CommandHandler[string] source;

    try {
        source = importFromSharedLibrary(modulePath, prefix);
    }
    catch(Exception ex)
    {
        debug {stderr.writeln(ex);}
        return false;
    }

    // Save on cache:
    program.importNamesFrom(source, prefix);
    sourcesCache[modulePath] = source;
    return true;
}

// Import commands from a .so:
CommandHandler[string] importFromSharedLibrary(
    string libraryPath, string moduleAlias
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

            // lh = "library handler"
            void* lh = dlopen(libraryPathZ, RTLD_LAZY);
            if (!lh)
            {
                lastError = cast(char *)dlerror();
                debug {stderr.writeln(" dlerror: ", lastError);}
                continue;
            }

            // Get the commands from inside the shared object:
            auto getCommands = cast(CommandHandler[string] function())dlsym(
                lh, "getCommands"
            );
            const char* error = dlerror();
            if (error)
            {
                throw new Exception("dlsym error: " ~ to!string(error));
            }
            auto libraryCommands = getCommands();

            return libraryCommands;
        }
    }
    throw new Exception("dlopen error: " ~ to!string(lastError));
};


void importNamesFrom(
    SubProgram program, CommandHandler[string] source, string prefix
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
        program.commands[cmdPath] = command;
    }
}
