module quarkhttp.config;

import std.file;
import std.json;
import std.stdio;
import std.conv;


class Config
{
public:
	JSONValue[string] config;

	this(string config)
	{
		try
		{
			this.config = parseJSON(config).object;
		}
		catch (Throwable exception)
		{
			writeln("error: ", exception.toString());
			return;
		}

	}

	~this()
	{

	}

}
