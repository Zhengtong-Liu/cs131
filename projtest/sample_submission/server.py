import asyncio
import message


class Server:
    def __init__(self, name, ip='127.0.0.1', port=8888, message_max_length=1e6):
        self.name = name
        self.ip = ip
        self.port = port
        self.message_max_length = int(message_max_length)

    async def handle_echo(self, reader, writer):
        """
        on server side
        """
        data = await reader.read(self.message_max_length)
        message = data.decode()
        print("{} received {}".format(self.name, message))

        sendback_message = message

        print("{} send: {}".format(self.name, sendback_message))
        writer.write(sendback_message.encode())
        await writer.drain()

        writer.close()

    async def run_forever(self):
        server = await asyncio.start_server(self.handle_echo, self.ip, self.port)

        # Serve requests until Ctrl+C is pressed
        print(f'serving on {server.sockets[0].getsockname()}')
        async with server:
            await server.serve_forever()
        # Close the server
        server.close()


def main():

    server = Server('Riley')
    try:
        server_message = message.ServerMessage()
        asyncio.run(server.run_forever())
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()