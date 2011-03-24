import std.conv;
import std.file;
import std.path;
import std.regexp;
import std.stdio;
import std.string;
import std.socket;
import std.uri;
import std.c.stdlib;
import core.thread;


version (linux)
    import core.stdc.signal;


enum RequestMethod { OPTIONS, GET, HEAD, POST, PUT, DELETE, TRACE, CONNECT, UNKNOWN }

struct RequestLine
{
    RequestMethod method;
    string uri;
}

struct Header
{
}

struct HTTPRequest
{
   

    static const string
        VERSION_1_1 = "HTTP/1.1";
    
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

    /* Receives request from client
     */
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

    /* Parses HTTP GET request and returns the requested object name
     */
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
    }


    //----------

    /* Receives, parses and returns HTTP request line with decoded URI.
     */
    RequestLine receiveRequestLine()
    {
        string request_line;
        char[1] buf;

        bool received = false;

        while (client.receive(buf))
        {
            if (buf[0] == '\n' && request_line.length > 0 && request_line[$ - 1] == '\r')
            {
                received = true;
                request_line = request_line[0 .. $ - 1];
                break;
            }

            request_line ~= buf[0];
        }

        if (!received)
            throw new Exception("Could not receive request line");

        auto valid_format = RegExp(`(\w+) ([^ ]+) ([^ ]+)`);

        if (request_line != valid_format)
            throw new Exception("Invalid request line format: " ~ request_line);

        enum RequestMethod[string] methods =
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

        auto parts = valid_format.search(request_line);

        auto known_method = parts[1] in methods;
        auto method = known_method ? *known_method : RequestMethod.UNKNOWN;

        return RequestLine(method, std.uri.decodeComponent(parts[2]));
    }
    
    //----------
    

    void run()
    {
        scope (exit) client.close();

        try
            auto request_line = receiveRequestLine();
        catch (Throwable exception)
            sendErrorPage(HTTP_STATUS_NOT_IMPLEMENTED, "Cannot process the request");

        string request;
        char[1] buf;

        while (client.receive(buf))
            request ~= buf[0];

        writeln(request);

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

extern (C) void catch_int(int sig_num)
{
    server.shutdown(SocketShutdown.BOTH);
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
    server.bind(new InternetAddress(80));
    server.listen(1);

    scope (exit) server.shutdown(SocketShutdown.BOTH);

    while (true && !stdin.eof())
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
