import std.c.stdlib;
import std.file;
import std.path;
import std.socket;
import std.stdio;
import quarkhttp.server;

version (linux)
    import core.stdc.signal;


Server server = null;


extern (C) void catch_int(int sig_num)
{
    server.stop();
    exit(EXIT_FAILURE);
}


void main()
{
    version (linux)
        signal(SIGINT, &catch_int);

    server = new Server;
    server.start(getcwd());
}
