module lsp::transport;
import std::io;
import std::core::string;
import std::collections::list;

struct LSPMessage
{
	String content_type;
	usz content_length;
	String content;
}

struct LSPTransport
{
	InStream input;
	OutStream output;
	Allocator allocator;
}

faultdef INVALID_HEADER;
faultdef CONTENT_TOO_LARGE;

const usz MAX_CONTENT_LENGTH = 1024 * 1024 * 10; // 10MB max

fn LSPTransport* LSPTransport.init(&self, InStream input, OutStream output, Allocator allocator)
{
	self.input = input;
	self.output = output;
	self.allocator = allocator;
	return self;
}

fn LSPTransport* LSPTransport.init_stdio(&self, Allocator allocator)
{
	return self.init(io::stdin(), io::stdout(), allocator);
}

fn String? LSPTransport.read_line(&self)
{
	@pool()
	{
		DString line = dstring::temp_with_capacity(256);
		
		while (true)
		{
			char? c = self.input.read_byte();
			if (catch err = c)
			{
				if (err == io::EOF)
				{
					if (line.len() == 0) return io::EOF?;
					break;
				}
				return err?;
			}
			
			if (c == '\n') break;
			if (c != '\r') line.append_char(c);
		}
		
		return line.copy_str(self.allocator);
	};
}

fn LSPMessage? LSPTransport.read_message(&self)
{
	LSPMessage msg = { .content_type = "application/vscode-jsonrpc; charset=utf-8" };
	
	@pool()
	{
		while (true)
		{
			String? line = self.read_line();
			if (catch err = line)
			{
				if (err == io::EOF) return io::EOF?;
				return err?;
			}
			
			if (line.len == 0) break; // Empty line signals end of headers
			
			if (line.starts_with("Content-Length: "))
			{
				String length_str = line[16..];
				usz? content_len = length_str.to_uint();
				if (catch err = content_len) return INVALID_HEADER?;
				
				if (content_len > MAX_CONTENT_LENGTH) return CONTENT_TOO_LARGE?;
				msg.content_length = content_len;
			}
			else if (line.starts_with("Content-Type: "))
			{
				msg.content_type = line[14..].copy(self.allocator);
			}
		}
		
		if (msg.content_length == 0) return INVALID_HEADER?;
		
		char[] content_buffer = allocator::alloc_array(self.allocator, char, msg.content_length);
		defer allocator::free(self.allocator, content_buffer);
		
		usz bytes_read = 0;
		
		while (bytes_read < msg.content_length)
		{
			usz remaining = msg.content_length - bytes_read;
			usz? read_result = self.input.read(content_buffer[bytes_read:remaining]);
			if (catch err = read_result)
			{
				if (err == io::EOF) return io::UNEXPECTED_EOF?;
				return err?;
			}
			if (read_result == 0) break; // No more data to read
			bytes_read += read_result;
		}
		
		msg.content = ((String)content_buffer).copy(self.allocator);
		return msg;
	};
}

fn void? LSPTransport.write_message(&self, String content)
{
	@pool()
	{
		DString header = dstring::temp_with_capacity(128);
		header.appendf("Content-Length: %d\r\n\r\n", content.len);
		
		self.output.write(header.str_view())!;
		self.output.write(content)!;
		if (&self.output.flush) self.output.flush()!;
	};
}

fn void? LSPTransport.write_response(&self, String json_response)
{
	return self.write_message(json_response);
}

fn void? LSPTransport.write_notification(&self, String json_notification)
{
	return self.write_message(json_notification);
}