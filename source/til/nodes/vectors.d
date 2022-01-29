module til.nodes.vectors;

import til.nodes;


CommandsMap bytesVectorCommands;


class BytesVector : Item
{
    byte[] values;

    this()
    {
        this.type = ObjectType.Vector;
        this.typeName = "bytes.vector";
        this.commands = bytesVectorCommands;
    }

    override string toString()
    {
        return (
            this.typeName ~ ":"
            ~ to!string(
                this.values.map!(x => to!string(x)).join(" ")
            )
        );
    }
}
