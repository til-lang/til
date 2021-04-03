module til.libs.posix.shell;

import til.escopo;
import til.nodes;


class Shell : Escopo
{
    Result cmd_ls(NamePath path, Args arguments)
    {
        // TESTE:
        return new SubList(arguments);
    }

    override void loadCommands()
    {
        this.commands["ls"] = &cmd_ls;
    }
}
