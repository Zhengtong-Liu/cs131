import asyncio
import argparse
import logging
import sys
import time
import json
import aiohttp
from collections import defaultdict

API_KEY = 'AIzaSyAiVWcBlgHPhyV_54ZBoZaijPV0Md7Ii94'

#12515 ~ 12519
server_nodes = {"Riley": 8000, "Jaquez": 8001, "Juzang": 8002, "Campbell": 8003, "Bernard": 8004}
server_edges = {
    "Riley": ["Jaquez", "Juzang"],
    "Jaquez": ["Riley", "Bernard"],
    "Juzang": ["Campbell"],
    "Campbell": ["Juzang", "Bernard"],
    "Bernard": ["Jaquez", "Juzang", "Campbell"]
}


class ServerMessage:
    def __init__(self, server_name="whatever_server"):
        self.server_name = server_name
        self.known_command = ["WHATSAT", "IAMAT"]
        self.time = dict()
        self.history = dict()

    async def parse_message(self, message):
        message_list = [msg for msg in message.strip().split() if len(msg)]
        # if len(message_list) != 4:
        #     return "ERROR: invalid command length"
        if message_list[0] == "IAMAT":
            return await self.handle_i_am_at(message_list[1], message_list[2], message_list[3])
        elif message_list[0] == "WHATSAT":
            return await self.handle_whats_at(message_list[1], message_list[2], message_list[3])
        else:
            return f"? {message}"

    async def handle_i_am_at(self, client_id, coordinates, timestamp):
        flag = True
        coords = list(filter(None, coordinates.replace('-', '+').split('+')))
        if len(coords) != 2 or not (valid_float(coords[0]) and valid_float(coords[1])):
            flag = False
        if not valid_float(timestamp):
            flag = False
        if flag:
            time_diff = time.time() - float(timestamp)
            if time_diff > 0:
                time_str = f"+{time_diff}"
            else:
                time_str = f"{time_diff}"
            msg = f"AT {self.server_name} {time_str} {client_id} {coordinates} {timestamp}"
            self.history[client_id] = msg
            self.time[client_id] = float(timestamp)
        else:
            msg = f"? IAMAT {client_id} {coordinates} {timestamp}"
        return msg

    async def handle_whats_at(self, client_id, radius, max_results):
        flag = True
        coords = ""
        coordinates = ""
        if client_id not in self.history.keys():
            flag = False
        else:
            message_list = self.history[client_id].strip().split()
            coords = message_list[4]
            index_plus = coords.rfind('+')
            index_minus = coords.rfind('-')
            if index_plus < index_minus and index_minus:
                coordinates = f"{coords[:index_minus]}, {coords[index_minus:]}"
            elif index_minus < index_plus and index_plus:
                coordinates = f"{coords[:index_plus]}, {coords[index_plus:]}"
            else:
                sys.stderr.write(f"bad coordinate format: {coords}")
                sys.exit(1)
            if (not (valid_float(radius) and valid_float(max_results))) or \
                (int(radius) < 0 or int(radius) > 50) or \
                (int(max_results) < 0 or int(max_results) > 20):
                flag = False

        if flag:
            logging.info(f"start Nearby Search request at location {coords}")
            place_json = await self.request_place(coordinates, radius, max_results)
            google_api_feedback = json.dumps(place_json, indent=4)
            return self.history[client_id] + "\n" + google_api_feedback + "\n\n"
        else:
            return f"? WHATSAT {client_id} {radius} {max_results}"

    async def request_place(self, location, radius, max_result):
        url = f'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location={location}&radius={radius}&key={API_KEY}'
        async with aiohttp.ClientSession(
                connector=aiohttp.TCPConnector(ssl=False, ),
        ) as session:
            async with session.get(url) as resp:
                response = await resp.json()
        logging.debug(f"receive json result {response}")
        result_len = len(response["results"])
        logging.info(f"receive {result_len} results from the Google Places API")

        if result_len <= int(max_result):
            return response
        else:
            response["results"] = response["results"][:int(max_result)]
        return response


class Server:
    messages = defaultdict(set)

    def __init__(self, name, ip='127.0.0.1', port=8888, message_max_length=1e6):
        self.name = name
        self.ip = ip
        self.port = port
        self.message_max_length = int(message_max_length)
        self.server_msg = ServerMessage(self.name)

    async def handle_echo(self, reader, writer):
        """
        on server side
        """
        data = await reader.read(self.message_max_length)
        message = data.decode()
        logging.info(f"{self.name} received {message}")

        message_list = [msg for msg in message.strip().split() if len(msg)]
        if len(message_list) == 4:
            sendback_message = await self.server_msg.parse_message(message)
            if message_list[0] == "IAMAT" and sendback_message[0] != '?':
                logging.info(f"{self.name} start sharing message with other servers")
                await self.share_msg(sendback_message)
            logging.info(f"{self.name} send to client: {sendback_message}")
            writer.write(sendback_message.encode())
            await writer.drain()
            writer.close()
        elif len(message_list) == 6 and message_list[0] == 'AT':
            logging.info("receiving message from other server")
            if (message_list[3] not in self.server_msg.time.keys()) or \
                    (float(message_list[5]) > self.server_msg.time[message_list[3]]):
                logging.info(f"new message or update message from client {message_list[3]}")
                self.server_msg.time[message_list[3]] = float(message_list[5])
                self.server_msg.history[message_list[3]] = message
                await self.share_msg(message)
            else:
                logging.info(f"no need to update message from client {message_list[3]}")
        else:
            logging.info(f"? {message}")

    async def run_forever(self):
        server = await asyncio.start_server(self.handle_echo, self.ip, self.port)

        # Serve requests until Ctrl+C is pressed
        logging.info(f'serving on {server.sockets[0].getsockname()}')
        async with server:
            await server.serve_forever()
        logging.info(f'shutting down {server.sockets[0].getsockname()}')
        # Close the server
        server.close()

    async def share_msg(self, message):
        if self.name not in Server.messages[message]:
            Server.messages[message].add(self.name)
            for friend in server_edges[self.name]:
                try:
                    reader, writer = await asyncio.open_connection('127.0.0.1', server_nodes[friend])
                    logging.info(f'{self.name} send {message!r} to {friend}')
                    writer.write(message.encode())
                    await writer.drain()
                    logging.info(f'{self.name} close connection to {friend}')
                    writer.close()
                    await writer.wait_closed()
                except:
                    logging.info(f'Cannot write to {friend}')


def valid_float(num):
    try:
        float(num)
        return True
    except ValueError:
        return False


def main():
    parser = argparse.ArgumentParser('Server Argument Parser')
    parser.add_argument('server_name', type=str, help='required server name input')
    args = parser.parse_args()

    if args.server_name not in server_nodes:
        sys.stderr.write(f"Not a valid server name: {args.server_name}\n")
        sys.exit(1)
    logging_format = '%(levelname)s: %(message)s'
    logging.basicConfig(filemode='w+', filename=f"{args.server_name}.log", format=logging_format, level=logging.INFO)
    server = Server(name=args.server_name, port=server_nodes[args.server_name])
    try:
        asyncio.run(server.run_forever())
    except KeyboardInterrupt:
        logging.info(f"received keyboard Interrupt, goodbye from {args.server_name}")


if __name__ == '__main__':
    main()
