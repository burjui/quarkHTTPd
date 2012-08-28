module quarkhttp.server;

import std.file;
import std.path;
import std.socket;
import std.stdio;
import std.json;
import quarkhttp.response_thread;
import quarkhttp.config;

class Server
{
private:
    TcpSocket socket;
    JSONValue[string] config;

public:
    this(JSONValue[string] config)
    {
        this.config = config;
        socket = new TcpSocket;
    }

    ~this()
    {
        delete socket;
        socket = null;
    }

    void stop()
    {
        socket.shutdown(SocketShutdown.BOTH);
        socket.close();
    }

    void start(string root_path = ".")
    {
        assert(exists(root_path));
        
        with (socket)
        {
            setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
            bind(new InternetAddress(cast(ushort)this.config["server"].object["listen"].integer));
            listen(1);
        }

        scope (exit) stop();

        while (true)
        {
            auto client_socket = socket.accept();
            writeln(">> accepted a connection");
            
            auto response_thread = new ResponseThread(absolutePath(root_path), client_socket);

            try
                response_thread.start();
            catch (Throwable exception)
                writeln("Got an error: ", exception.toString());
        }
    }
}
