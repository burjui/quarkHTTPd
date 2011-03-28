module quarkhttp.core;


/+++++ Types, structures etc. +++++/

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

struct ResponseStatus
{
    uint   code;
    string reason;
}


/+++++ Constants +++++/

shared immutable string
    HTTP_VERSION_1_1 = "HTTP/1.1",
    BANNER = "quarkHTTPd 0.1 (C) 2009-2011 Artyom Borisovskiy";

shared immutable ResponseStatus
    STATUS_OK = { 200, "OK" },
    STATUS_NOT_FOUND = { 404, "Not found" },
    STATUS_INTERNAL_ERROR = { 500, "Internal Server Error" },
    STATUS_NOT_IMPLEMENTED = { 501, "Not implemented" };
