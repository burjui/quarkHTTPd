module quarkhttp.response_thread;

import core.thread;
import std.array;
import std.conv;
import std.file;
import std.path;
import std.regex;
import std.socket;
import std.stdio;
import std.string;
import std.uri;
import quarkhttp.core;
import quarkhttp.utils;


class Client
{
private:
    Socket socket;

public:
    this(Socket client_socket)
    {
        socket = client_socket;
    }
    

    void endSession()
    {
        socket.shutdown(SocketShutdown.BOTH);
        socket.close();
    }
    

    void sendResponse(in ResponseStatus status,
                      lazy const void[] message_body = null,
                      in string content_type = "text/html")
    {
        string status_line = format(HTTP_VERSION_1_1 ~ " %s %s" ~ CRLF,
            to!string(status.code), std.uri.encode(status.reason));

        string headers;

        if (content_type && content_type != "")
            headers ~= "Content-Type: " ~ std.uri.encode(content_type) ~ CRLF;

        headers ~= "Content-Length: " ~ to!string(message_body.length) ~ CRLF;

        string response = status_line ~ headers ~ CRLF;
        socket.send(response);

        if (message_body)
            socket.send(message_body);
    }


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

        writeln("REQUEST ", line);

        return RequestLine(method, uri);
    }


    /* Receives and returns HTTP headers.
     */
    Header[] receiveHeaders()
    {
        Header[] headers;
        
        for (string line = receiveLine(); !line.empty; line = receiveLine())
        {
            if (iswhite(line[0]))
            {
                if (headers.empty)
                    throw new Exception("Header starting from whitespace is invalid: `" ~ line ~ "'");

                headers.back.value ~= strip(line);
            }
            else
            {
                auto format_match = match(line, regex(`([^ ]+):(.+)`));

                if (line != format_match.hit())
                    throw new Exception("Invalid header format: `" ~ line ~ "'");

                with (format_match)
                    headers ~= Header(captures[1], strip(captures[2]));
            }
        }

        return headers;
    }


    void[] receiveMessageBody()
    {
        byte[] message_body;
        byte[16] buffer;

        for (auto received = socket.receive(buffer); received; received = socket.receive(buffer))
        {
            auto from = message_body.length - 1, to = from + received;
            message_body.length += received;
            message_body[from .. to] = buffer[0 .. received];
        }

        return message_body;
    }


    void sendErrorPage(in ResponseStatus status, in string message)
    {
        auto message_body = format("<h2>%d %s</h2><hr>%s", status.code, message, BANNER);
        sendResponse(status, cast(void[])message_body);
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
        
        while (socket.receive(buffer))
        {
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
}


class ResponseThread: Thread
{
private:
    alias bool delegate(in RequestLine request, in Header[] headers) RequestHandler;

    Client client;
    string root;
    
    
    bool processRequest(in RequestLine request, in Header[] headers, in RequestHandler[] handlers)
    {
        foreach (handle; handlers)
        {
            if (handle(request, headers))
                return true;
        }

        return false;
    }


    void run()
    {
        scope (exit)
            client.endSession();

        try
        {
            auto request_line = client.receiveRequestLine();
            
            if (request_line.method != RequestMethod.GET)
            {
                client.sendErrorPage(STATUS_NOT_IMPLEMENTED, "Unknown request method");
                return;
            }

            auto headers = client.receiveHeaders();

            if (!processRequest(request_line, headers,
                [
                    &fileSender,
                    &indexSender,
                    &dirLister
                ]))
            {
                client.sendErrorPage(STATUS_NOT_IMPLEMENTED, "Not implemented");
                return;
            }
        }
        catch (Throwable exception)
        {
            client.sendErrorPage(STATUS_INTERNAL_ERROR, "Internal server error");
            return;
        }
    }


    //----- HANDLERS -----//
    

    bool fileSender(in RequestLine request, in Header[] headers)
    {
        auto path = std.path.join(root, request.uri.skip("/"));
        writeln("SEND? ", path);
        
        auto result = sendFile(path);
        writefln(".. %s", result ? "OK" : "no");

        return result;
    }


    bool indexSender(in RequestLine request, in Header[] headers)
    {
        auto path = uri2local(request.uri);
        writeln("INDEX? ", path);
        
        auto result = path.exists && path.isDir && sendFile(std.path.join(path, "index.html"));
        writefln(".. %s", result ? "OK" : "no");
        
        return false;
    }


    bool dirLister(in RequestLine request, in Header[] headers)
    {
        auto path = uri2local(request.uri), host = getHeaderValue(headers, "Host");
        writeln("LIST? ", path);

        bool result;
        
        if (path.exists && path.isDir)
        {
            string page = "<html><body><pre>";
            
            foreach (filename; path.listDir)
            {
                auto
                    local_path = std.path.join(path, filename),
                    local_path_is_dir = (local_path.exists && local_path.isDir),
                    slash_if_dir = (local_path_is_dir ? "/" : ""),
                    url = format(`http://%s/%s/%s%s`, host, request.uri, filename, slash_if_dir),
                    prefix = (local_path_is_dir ? "DIR " : "    "),
                    link = format(`%s <a href="%s">%s</a><br/>`, prefix, url, filename);
                
                page ~= link;
            }

            page ~= "</pre></body></html>";
            client.sendResponse(STATUS_OK, page);
            
            result = true;
        }

        writefln(".. %s", result ? "OK" : "no");
        
        return result;
    }

    //--------------------//
    
    string getHeaderValue(in Header[] headers, string name)
    {
        foreach (header; headers)
        {
            if (header.name == name)
                return header.value;
        }
        
        return "";
    }
    

    bool sendFile(string path)
    {
        if (path.exists && path.isFile)
        {
            client.sendResponse(STATUS_OK, std.file.read(path), getMIMEType(path));
            return true;
        }
        
        return false;
    }


    string uri2local(string uri)
    {
        return std.path.join(root, uri.skip("/"));
    }


    string getMIMEType(string filename)
    {
        const string[string] types =
        [
            "html": "text/html",
            "txt":  "text/plain",
            "gif":  "image/gif",
            "jpg":  "image/jpeg"
        ];

        return types.get(getExt(filename), "application/octet-stream");
    }

public:
    this(string root, Socket client_socket)
    {
        client = new Client(client_socket);
        root = root;
        super(&run);
    }

    ~this()
    {
        delete client;
    }
}
