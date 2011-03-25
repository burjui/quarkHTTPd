import std.array;
import std.conv;
import std.file;
import std.path;
import std.regex;
import std.stdio;
import std.string;
import std.socket;
import std.uri;
import std.c.stdlib;
import core.thread;


version (linux)
    import core.stdc.signal;

static const string
   HTTP_VERSION_1_1 = "HTTP/1.1";

enum RequestMethod { OPTIONS, GET, HEAD, POST, PUT, DELETE, TRACE, CONNECT, UNKNOWN }

struct RequestLine
{
    RequestMethod method;
    string uri;
}

struct Header
{
    string name;
    string value;
}

struct HTTPRequest
{
    
    RequestMethod   method;
    string   uri;
    string   protocol_version;
    string[] headers;
    string   message_body;
}


struct HTTPStatus
{
    int    code;
    string reason;
}


shared immutable HTTPStatus
    HTTP_STATUS_OK = { 200, "OK" },
    HTTP_STATUS_NOT_FOUND = { 404, "Not found" },
    HTTP_STATUS_NOT_IMPLEMENTED = { 501, "Not implemented" };


class QuarkThread: Thread
{
private:
    const string
        CRLF = "\r\n",
        BANNER = "quarkHTTPd 0.1 (C) 2009-2011 Artyom Borisovskiy";

    Socket client;
    string root;

    /*
    string receiveRequest()
    {
        string request;
        char[1] buffer;
        uint newlines = 0;
        
        while (client.receive(buffer))
        {
            request ~= buffer;
            
            if (request.length >= 4 && request[$ - 4 .. $] == (CRLF ~ CRLF))
                break;
        }

        return request;
    }

    string parseGetRequest(in string request) const
    {
        string[] lines = splitlines(cast(string)request);
        auto request_regexp = RegExp("GET +(.+) +.*\n");

        string requested_object = "";

        if ((lines[0] ~ '\n') == request_regexp)
            requested_object = strip(request_regexp.replace("$1"));

        return requested_object;
    }


    void sendResponse(in HTTPStatus status, in void[] message_body = null, in string content_type = "text/html")
    {
        string status_line = format(HTTPRequest.VERSION_1_1 ~ " %s %s" ~ CRLF,
            to!string(status.code), std.uri.encode(status.reason));

        string headers;

        if (content_type && content_type != "")
            headers ~= "Content-Type: " ~ std.uri.encode(content_type) ~ CRLF;

        string response = status_line ~ headers ~ CRLF;
        client.send(response);

        if (message_body)
            client.send(message_body);
    }


    void sendErrorPage(in HTTPStatus status, in string message)
    {
        auto message_body = "<h2>" ~ message ~ "</h2><hr>" ~ BANNER;
        sendResponse(status, message_body);
    }*/


    //----------

    /* Receives, parses and returns HTTP request line with decoded URI.
     */
    RequestLine receiveRequestLine()
    {
        auto line = receiveLine();
        auto format_match = std.regex.match(line, regex(`(\w+) ([^ ]+) ([^ ]+)`));

        if (line != format_match.hit())
            throw new Exception("Invalid request line format: " ~ line);

        if (format_match.captures[3] != HTTP_VERSION_1_1)
            throw new Exception("Invalid protocol version: " ~ format_match.captures[3]);

        const RequestMethod[string] methods =
        [
            "OPTIONS": RequestMethod.OPTIONS,
            "GET": RequestMethod.GET,
            "HEAD": RequestMethod.HEAD,
            "POST": RequestMethod.POST,
            "PUT": RequestMethod.PUT,
            "DELETE": RequestMethod.DELETE,
            "TRACE": RequestMethod.TRACE,
            "CONNECT": RequestMethod.CONNECT
        ];

        auto method = methods.get(format_match.captures[1], RequestMethod.UNKNOWN);
        auto uri = std.uri.decodeComponent(format_match.captures[2]);

        return RequestLine(method, uri);
    }

    
    /* Receives a line from client, line ending is CRLF.
     * Throws an exception if line ending was not received
     */
    string receiveLine()
    {
        string line;
        char[1] buffer, previous;
        bool received_crlf;

        /* Possible optimization (part 1)
         * line.reserve(16);
         */
        
        while (client.receive(buffer))
        {
            //writeln("> ", buffer);
            if (previous == "\r" && buffer == "\n")
            {
                received_crlf = true;
                --line.length;
                break;
            }

            /* Possible optimization (part 2)
             * if (line.length == line.capacity)
             *   line.reserve(line.capacity * 2);
             */

            line ~= buffer;
            previous = buffer;
        }

        if (!received_crlf)
            throw new Exception("Did not receive line ending");

        return line;
    }


    /+string receiveHeaderLine()
    {
        string header_line;
        char[1] buf;

        bool received;

        while (client.receive(buf))
        {
            if (buf[0] == '\n' && header_line.length > 0 && header_line[$ - 1] == '\r')
            {
                received = true;
                header_line = header_line[0 .. $ - 1];
                break;
            }

            header_line ~= buf[0];
        }

        if (!received)
            throw new Exception("Could not receive header line");

        return header_line;
    }
    

    Header[] receiveRequestHeaders()
    {
        Header[] headers;

        bool received;
        char[2] crlf;

        client.receive(crlf, SocketFlags.PEEK);

        /*auto valid_format = RegExp(`([^ ]+):([^ ]+)`);

        if (header_line != valid_format)
            throw new Exception("Invalid header format: " ~ header_line)*/
        
        /*string header_line;
        char[1] buf;

        bool received = false;

        while (client.receive(buf))
        {
            if (buf[0] == '\n' && header_line.length > 0 && header_line[$ - 1] == '\r')
            {
                received = true;
                header_line = header_line[0 .. $ - 1];
                break;
            }

            header_line ~= buf[0];
        }

        if (!received)
            throw new Exception("Could not receive headers");

        auto valid_format = RegExp(`([^ ]+):([^ ]+)`);

        if (header_line != valid_format)
            throw new Exception("Invalid header format: " ~ header_line);*/

        return headers;
    }
    +/
    
    //----------
    

    void run()
    {
        scope (exit) client.close();

        /+try
            auto request_line = receiveRequestLine();
        catch (Throwable exception)
            sendErrorPage(HTTP_STATUS_NOT_IMPLEMENTED, "Cannot process the request");

        //auto headers = receiveRequestHeaders();

        string request;
        char[1] buf;

        while (client.receive(buf))
            request ~= buf[0];

        writeln(request);+/

        
        try
        {
            auto request_line = receiveRequestLine();
            with (request_line)
                writefln("method: %s, uri: %s", method, uri);
            
            for (string line = receiveLine(); !line.empty; line = receiveLine())
                writeln(".. ", line);
        }
        catch (Throwable exception)
        {
            writeln("! ", exception.toString());
        }

        writeln("<< closing connection");
        

        /*
        string request = receiveRequest();
        string object_name = parseGetRequest(request);
        string filename = std.uri.decodeComponent(object_name);
    
        if (filename[0] == '/')
            filename = filename[1 .. $];
        
        filename = std.path.join(rel2abs(getcwd()), filename);

        if (exists(filename) && isDir(filename))
            filename = std.path.join(filename, "index.html");

        if (exists(filename))
        {
            char[] content = cast(char[])std.file.read(filename);
            
            client.send("HTTP/1.1 200 OK" ~ CRLF);
            client.send("Content-Type: " ~
                (getExt(filename) == "html" ? "text/html" : "application/octet-stream") ~ CRLF ~
                "Content-Length: " ~ to!(string)(content.length) ~ CRLF ~ CRLF);
            client.send(content);
            writefln("OK");
        }
        else
            sendErrorPage(HTTP_STATUS_NOT_FOUND, format("'%s' not found on server", filename));
        */
    }

public:
    this(string root, Socket client)
    {
        this.client = client;
        this.root = root;
        super(&run);
    }
}


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
        setOption(SocketOptionLevel.IP, SocketOption.REUSEADDR, 1);
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
        {
            writeln("Got an error: ", exception.toString());
        }
    }
}
