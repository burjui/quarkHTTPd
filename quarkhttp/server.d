module quarkhttp.server;

import std.file;
import std.path;
import std.socket;
import std.stdio;
import quarkhttp.response_thread;


class Server
{
private:
    TcpSocket socket;
    

public:
    this()
    {
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
            bind(new InternetAddress(80));
            listen(1);
        }

        scope (exit) stop();

        while (true)
        {
            auto client_socket = socket.accept();
            writeln(">> accepted a connection");
            
            auto response_thread = new ResponseThread(rel2abs(root_path), client_socket);

            try
                response_thread.start();
            catch (Throwable exception)
                writeln("Got an error: ", exception.toString());
        }
    }
}
