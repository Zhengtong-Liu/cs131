import asyncio
import argparse
import logging
import sys
import time
import json
import aiohttp

API_KEY = 'AIzaSyAiVWcBlgHPhyV_54ZBoZaijPV0Md7Ii94'

#12515 ~ 12519
server_nodes = {"Riley": 12515, "Jaquez": 12516, "Juzang": 12517, "Campbell": 12518, "Bernard": 12519}
server_edges = {
    "Riley": ["Jaquez", "Juzang"],
    "Jaquez": ["Riley", "Bernard"],
    "Juzang": ["Riley", "Campbell", "Bernard"],
    "Campbell": ["Juzang", "Bernard"],
    "Bernard": ["Jaquez", "Juzang", "Campbell"]
}


class Server:
    def __init__(self, name, ip='127.0.0.1', port=8888, message_max_length=1e6):
        self.name = name
        self.ip = ip
        self.port = port
        self.message_max_length = int(message_max_length)
        self.time = dict()
        self.history = dict()

    async def handle_echo(self, reader, writer):
        """
        on server side
        """
        data = await reader.read(self.message_max_length)
        message = data.decode()
        logging.info(f"{self.name} received {message}")

        message_list = [msg for msg in message.strip().split() if len(msg)]
        # if the message is split into four parts, it should be IAMAT or WHATSAT message;
        # otherwise, the message is invalid
        if len(message_list) == 4:
            if message_list[0] == "IAMAT":
                sendback_message = await self.handle_i_am_at(message)
                logging.info(f"{self.name} send to client: {sendback_message}")
                writer.write(sendback_message.encode())
                logging.info(f"{self.name} finish writing to client")
                await writer.drain()
                writer.close()
            elif message_list[0] == "WHATSAT":
                sendback_message = await self.handle_whats_at(message)
                logging.info(f"{self.name} send to client: {sendback_message}")
                writer.write(sendback_message.encode())
                logging.info(f"{self.name} finish writing to client")
                await writer.drain()
                writer.close()
            else:
                sendback_message = f"? {message}"
                logging.info(f"Invalid message: {sendback_message}")
                writer.write(sendback_message.encode())
                logging.info(f"{self.name} finish writing to client")
                await writer.drain()
                writer.close()
        # if the message is split into six parts, it should message from other servers;
        # update the message if this is a new message or the message coming has a later timestamp
        elif len(message_list) == 6 and message_list[0] == 'AT':
            logging.info("receiving message from other server")
            if message_list[3] in self.time.keys():
                if float(message_list[5]) > self.time[message_list[3]]:
                    logging.info(f"update message from client {message_list[3]}")
                    self.time[message_list[3]] = float(message_list[5])
                    self.history[message_list[3]] = message
                    await self.share_msg(message)
                else:
                    logging.info(f"no need to update message from client {message_list[3]}")
            else:
                logging.info(f"new message from client {message_list[3]}")
                self.time[message_list[3]] = float(message_list[5])
                self.history[message_list[3]] = message
                await self.share_msg(message)
        # otherwise, the message is invalid
        else:
            sendback_message = f"? {message}"
            logging.info(f"Invalid message: {sendback_message}")
            writer.write(sendback_message.encode())
            logging.info(f"{self.name} finish writing to client")
            await writer.drain()
            writer.close()

    # handle IAMAT message, check the coordinates, calculate the time difference, return the AT message
    async def handle_i_am_at(self, message):
        message_list = [msg for msg in message.strip().split() if len(msg)]
        client_id = message_list[1]
        coordinates = message_list[2]
        timestamp = message_list[3]
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
            msg = f"AT {self.name} {time_str} {client_id} {coordinates} {timestamp}"
            self.history[client_id] = msg
            self.time[client_id] = float(timestamp)
            logging.info(f"{self.name} start sharing message with other servers")
            await self.share_msg(msg)
        else:
            msg = f"? {message}"
        return msg

    # handle WHATSAT message, check coordinates, radius and max_results, request location information
    # and return the AT message with json result
    async def handle_whats_at(self, message):
        message_list = [msg for msg in message.strip().split() if len(msg)]
        client_id = message_list[1]
        radius = message_list[2]
        max_results = message_list[3]
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
            return f"? {message}"

    # request the location information from Google Places API
    async def request_place(self, location, radius, max_result):
        url = f'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location={location}&radius={radius}&key={API_KEY}'
        async with aiohttp.ClientSession() as session:
            async with session.get(url) as resp:
                res= await resp.text()
        logging.debug(f"receive json result {res}")
        response = json.loads(res)
        try:
            result_len = len(response["results"])
            logging.info(f"receive {result_len} results from the Google Places API")
        except KeyError:
            logging.debug(f"Invalid Response from the Google Places API:{response}")
            sys.stderr.write(f"Invalid Response from the Google Places API:{response}")
            sys.exit(1)

        if result_len <= int(max_result):
            return response
        else:
            response["results"] = response["results"][:int(max_result)]
        return response

    # run the server
    async def run_forever(self):
        server = await asyncio.start_server(self.handle_echo, self.ip, self.port)

        # Serve requests until Ctrl+C is pressed
        logging.info(f'serving on {server.sockets[0].getsockname()}')
        async with server:
            await server.serve_forever()
        logging.info(f'shutting down {server.sockets[0].getsockname()}')
        # Close the server
        server.close()

    # share messages to neighbors using the flood algorithm referred from TA hint repo
    async def share_msg(self, message):
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


# check whether num is a valid float number
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
