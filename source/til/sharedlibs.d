module til.sharedlibs;

import core.sys.posix.dlfcn;
import std.string : toStringz;

import til.nodes;


class DynamicLib
{
    void* handler;
    bool success;
    string errorMessage;

    void call(string functionName)
    {
        fnCall(this.handler, functionName.toStringz);
    }
    void close()
    {
        dlclose(this.handler);
    }
}


DynamicLib[string] sharedLibraries;


void fnCall(void* lh, const(char*) functionNameZ)
{
    void function() fn = cast(void function())dlsym(lh, functionNameZ);
    const char* error = dlerror();
    if (error)
    {
        throw new Exception("dlsym error: " ~ to!string(error));
    }
    fn();
}

void lhUnload(string libraryName)
{
    auto lib = (libraryName in sharedLibraries);
    if (lib is null)
    {
        throw new Exception(libraryName ~ " was not loaded");
    }

    lib.close();
    sharedLibraries.remove(libraryName);
}

DynamicLib loadDynamicLib(string libraryPath)
{
    // TODO: initialize things on DynamicLib constructor
    // and throw Exception if some error occur.
    auto result = new DynamicLib();

    result.handler = dlopen(libraryPath.toStringz, RTLD_LAZY);
    if (result.handler is null)
    {
        result.success = false;
        const char* error = dlerror();
        result.errorMessage = "dlopen error: " ~ to!string(error);
    }
    else {
        result.success = true;
    }
    return result;
}
