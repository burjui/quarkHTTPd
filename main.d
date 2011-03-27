import std.c.stdlib;
import std.file;
import std.path;
import std.socket;
import std.stdio;
import quarkhttp.thread;

version (linux)
    import core.stdc.signal;


TcpSocket server = null;


void stopServer()
{
    server.shutdown(SocketShutdown.BOTH);
    server.close();
}


extern (C) void catch_int(int sig_num)
{
    stopServer();
    exit(EXIT_FAILURE);
}


void main()
{
    version (linux)
    {
        signal(SIGINT, &catch_int);
    }

    auto root = rel2abs(getcwd());
    server = new TcpSocket;

    with (server)
    {
        setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
        bind(new InternetAddress(80));
        listen(1);
    }

    scope (exit) stopServer();
    
    while (true)
    {
        auto client = server.accept();
        writeln(">> accepted a connection");
        
        auto response_thread = new QuarkThread(root, client);

        try
            response_thread.start();
        catch (Throwable exception)
            writeln("Got an error: ", exception.toString());
    }
}
