import std.c.stdlib;
import std.file;
import std.path;
import std.socket;
import std.stdio;
import std.conv;
import quarkhttp.config;
import quarkhttp.server;

version (linux)
    import core.stdc.signal;


Server server = null;
Config config = null;


extern (C) void catch_int(int sig_num)
{
    server.stop();
    exit(EXIT_FAILURE);
}


void main()
{
    version (linux)
        signal(SIGINT, &catch_int);


    auto content = to!string(read("quarkd.conf"));
    config = new Config(content);

    server = new Server(config.config);
    server.start(getcwd());
}
