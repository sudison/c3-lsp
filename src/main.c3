module c3lsp;
import std::io;
import parser;
import lsp::server;

fn int main(String[] args)
{
	@pool()
	{
		LSPServer server;
		server.init_stdio(allocator::heap());
		
		if (catch err = server.run())
		{
			io::eprintn("LSP server error occurred");
			return 1;
		}
		
		return 0;
	};
}
