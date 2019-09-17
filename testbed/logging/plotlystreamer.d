module logging.plotlystreamer;

import std.datetime;
import std.net.curl;
import std.socket;
import std.stdio;

class plotlyStreamer
{
private:
	Socket _sock;
	string _token; 
	string _buffer;
	StopWatch _sw;

	import std.file;
	File fitLog;

	
public:
	this(string token_)
	{
		_token = "plotly-streamtoken: " ~ token_ ~"\r\n";
		_sock = new Socket(AddressFamily.INET,SocketType.STREAM);
		_sw = StopWatch(AutoStart.yes);
	}

	~this()
	{
		debug writeln("closing socket.");
		_sock.close();
	}
	
	void makePlot()
	{
		enum loginData = "un=Trollgeir&key=76cu35pz13&origin=plot&platform=dlang&args=[{
  \"x\": [],
  \"y\": [],
  \"type\": \"lines\",
  \"mode\": \"lines\",
  \"stream\": {
      \"token\": \"v5q2emjeve\"
      }
}]
 &kwargs={\"filename\": \"streamtest\",
		\"fileopt\": \"overwrite\",
		\"layout\": {
			\"title\": \"Fitness data\"
		},
			\"world_readable\": true
	}";
		
		writeln(post("plot.ly/clientresp",loginData));
	}
	
	
	void connect()
	{
		Address[] addresses = getAddress("stream.plot.ly", 80);
		_sock.connect(addresses[0]);
		string header = "POST / HTTP/1.1\r\nUser-Agent: Dlang\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n";
		_sock.send(header ~ _token);
		_sock.send("\r\n"); // End of Header
//		makePlot();
	}
	
	void resetGraph()
	{
		writeln("Resetting graph");
		send("{\"x\":[],\"y\":[],\"z\":[] }\n");
	}
	
	
	void send(string data)
	{
		_buffer ~= data;
		
		if(_sw.peek.msecs > 50) // Can't send to plotly more than once every 50ms
		{
			debug writeln("sending data: ",_buffer);
			import std.string;
			string hex = format("%x",_buffer.length) ~ "\r\n";
			_sock.send(hex ~ _buffer ~ "\r\n");
			_buffer = "";
			_sw.reset();
			_sw.start();
		}
		else debug writeln("holding data, plotly not ready..(",_sw.peek.msecs,"ms < 50ms)");
	}
	
	void sendXY(in float x, in float y)
	{
		import std.string;

		string xString = format("%s",x);
		string yString = format("%s",y);	
//		string msg = "{\"x\":" ~ xString ~ ",\"y\":"~ yString ~ ",\"z\":"~ zString ~ "}\n";
		string msg = "{\"x\":" ~ xString ~ ",\"y\":"~ yString ~ "}\n";
		send(msg);
	}
	void keepAlive()
	{
		send("\n");
	}
}

