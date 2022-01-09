import logging
import asyncio
import argparse
import time
import aiohttp
import json
# my ports are: 12355 through 12359
# serverstats = {
#     "Riley": [12355, "Jaquez","Juzang"],
#     "Jaquez":[12356,"Riley","Bernard"],
#     "Juzang":[12357,"Riley","Bernard","Campbell"],
#     "Campbell":[12358,"Bernard","Juzang"],
#     "Bernard":[12359,"Jaquez","Juzang","Campbell"]
# }
serverstats = {
    "Riley": [8000, "Jaquez","Juzang"],
    "Jaquez":[8001,"Riley","Bernard"],
    "Juzang":[8002,"Riley","Bernard","Campbell"],
    "Campbell":[8003,"Bernard","Juzang"],
    "Bernard":[8004,"Jaquez","Juzang","Campbell"]
}
API = "AIzaSyBHmTd5SC9IqUM8FJ4FERJA2SDxZEQ9-OM"
#the following class is adapted from TA hint repo: https://github.com/CS131-TA-team/UCLA_CS131_CodeHelp/blob/master/Python/echo_server.py
class TAServer:
    def __init__(self, name, port,ip='127.0.0.1', message_max_length=1e6):
        self.name = name
        self.ip = ip
        self.port = port
        self.message_max_length = int(message_max_length)
        self.clienthistory = dict()

    async def processcommand(self, reader, writer):
        startsuccessmessage = f'Server {self.name} start to process command'
        print(startsuccessmessage)
        logging.info(startsuccessmessage)

        data = await reader.read(self.message_max_length)
        message = data.decode()
        result = ""
        # addr = writer.get_extra_info('peername')
        readingmessage = f'Server {self.name} got |{message}|'
        print(readingmessage)
        logging.info(readingmessage)
        splitmessage = []

        errorsplit = False
        try:
            splitmessage = message.split()
        except:
            errormessage = f'Server {self.name} got |{message}| which cannot be split'
            print(errormessage)
            logging.info(errormessage)
            result = "? " +message
            errorsplit = True
        interconnectflag = False
        if not errorsplit:
            if len(splitmessage) == 4:
                if splitmessage[0] == "IAMAT":
                    result = await self.processiamat(message,splitmessage)
                elif splitmessage[0] == "WHATSAT":
                    result = await self.processwhatsat(message,splitmessage)
                else:
                    result = "? " + message
            elif len(splitmessage) == 7 and splitmessage[0] == "INTERCONNECT":
                await self.processinterconnect(message, splitmessage)
                interconnectflag = True
            else:
                result = "? " + message
        if not interconnectflag:
            serverback = f'Server {self.name} start to write back |{result}| after processing |{message}|'
            print(serverback)
            logging.info(serverback)
            writer.write(result.encode())
            await writer.drain()
        

        closemessage = f'Server {self.name} finish processing and is about to close connection'
        print(closemessage)
        logging.info(closemessage)
        writer.close()
    async def processwhatsat(self, whatsatmessage, whatsatsplit):
        startmessage = f'Server {self.name} start process the whatsat message {whatsatmessage}'
        print(startmessage)
        logging.info(startmessage)
        result = ""
        clientname = ""
        radius = 0
        boundnumber = 0
        validconversion = True
        try:
            clientname = str(whatsatsplit[1])
            radius = int(whatsatsplit[2])
            boundnumber = int(whatsatsplit[3])
        except:
            validconversion = False
        if not validconversion:
            result = "? " + whatsatmessage
        elif (not str(whatsatsplit[2]).isnumeric()) or (not str(whatsatsplit[3]).isnumeric()):
            result = "? " + whatsatmessage
        elif  radius < 0 or radius > 50 or boundnumber < 0 or boundnumber > 20:
            result = "? " + whatsatmessage
        elif clientname not in self.clienthistory.keys():
            result = "? " + whatsatmessage 
        else:
            currentlocation = self.clienthistory[clientname]
            currentlocation = currentlocation.split()
            currentlocation = currentlocation[4]
            googleresult = await self.getgoogleresult(currentlocation, radius, boundnumber)
            # googleresult = str(googleresult).rstrip('\n')
            if googleresult == None:
                result = "? " + whatsatmessage
            else:
                # googleresult = str(googleresult).rstrip('\n')
                result = f"{self.clienthistory[clientname]}\n{googleresult}\n"
        closemessage = f'Server {self.name} finish processing the whatsat message {whatsatmessage}'
        print(closemessage)
        logging.info(closemessage)
        return result


    async def processiamat(self, iamatmessage, iamatsplit):
        startmessage = f'Server {self.name} start process the iamat message {iamatmessage}'
        print(startmessage)
        logging.info(startmessage)
        giventime = 0
        try:
            giventime = float(iamatsplit[3])
        except:
            print("Error1")
            return "? " + iamatmessage
        originallocation = str(iamatsplit[2])

        numberofsigns = 0
        signslocation = []
        for i in range(len(originallocation)):
            if originallocation[i] == "+" or originallocation[i] == "-":
                numberofsigns += 1
                signslocation.append(i)
        if numberofsigns != 2:
            print("Error4")
            return "? " + iamatmessage
        elif (len(originallocation)-1) in signslocation or 0 not in signslocation:
            print("Error5")
            return "? " + iamatmessage
        else: 
            lat = originallocation[:signslocation[1]]
            lon = originallocation[signslocation[1]:]
            try:
                float(lat)
                float(lon)
            except:
                print("Error6")
                return "? " +iamatmessage
            
        timedifference = time.time() - giventime
        strtimediff = ""
        if timedifference > 0:
            strtimediff = "+" + str(timedifference)
        else:
            strtimediff = str(timedifference)
        withoutfirstmessage = ' '.join(iamatsplit[1:])
        resultmessage = f'AT {self.name} {strtimediff} {withoutfirstmessage}'
        self.clienthistory[iamatsplit[1]] = resultmessage
        startupdate = f'Server {self.name} finish processing the iamat message |{iamatmessage}| and begin flooding'
        print(startupdate)
        logging.info(startupdate)
        await self.simpleflood(resultmessage)
        finishupdate = f'Server {self.name} finish flood the iamat message |{iamatmessage}|'
        print(finishupdate)
        logging.info(finishupdate)
        return resultmessage
                



    async def processinterconnect(self, intermessage, intersplit):
        startinerconnect = f'Server {self.name} start to process interconnect message |{intermessage}|'
        print(startinerconnect)
        logging.info(startinerconnect)
        realinfo = intersplit[1:]
        clientname = str(realinfo[3])
        realmessage = ' '.join(realinfo)
        if clientname not in self.clienthistory.keys():
            self.clienthistory[clientname] = realmessage
            await self.simpleflood(realmessage)
        else:
            messagetime = float(realinfo[5])
            currentstored = self.clienthistory[clientname]
            currentstored = currentstored.split()
            storedtime = float(currentstored[5])
            if storedtime < messagetime:
                self.clienthistory[clientname] = realmessage
                await self.simpleflood(realmessage)
        finishinterconnect = f'Server {self.name} finish process interconnect message |{intermessage}|'
        print(finishinterconnect)
        logging.info(finishinterconnect)

    async def simpleflood(self, floodmessage): #adapted from TA discussion 1b client example
        startflood = f'Server {self.name} start to flood the message |{floodmessage}|'
        print(startflood)
        logging.info(startflood)
        global serverstats
        childlist = serverstats[self.name][1:]
        sendmessage = f'INTERCONNECT {floodmessage}'
        for eachchild in childlist:
            childport = int(serverstats[eachchild][0])
            try:
                childreader, childwriter = await asyncio.open_connection('127.0.0.1', childport)
                childwriter.write(sendmessage.encode())
                await childwriter.drain()
                childwriter.close()
            except:
                flooderror = f'Server {self.name} flood error message: |{floodmessage}| to server: {eachchild}'
                print(flooderror)
                logging.info(flooderror)
        floodfinish = f'Server {self.name} flood finish message: |{floodmessage}|'
        print(floodfinish)
        logging.info(floodfinish)

    async def getgoogleresult(self, currentlocation, radius, boundnumber):
        startmessage = f'Server {self.name} start process get google with location  {currentlocation}'
        print(startmessage)
        logging.info(startmessage)
        numberofsigns = 0
        signslocation = []
        for i in range(len(currentlocation)):
            if currentlocation[i] == "+" or currentlocation[i] == "-":
                numberofsigns += 1
                signslocation.append(i)
        if numberofsigns != 2:
            return None
        elif (len(currentlocation)-1) in signslocation or 0 not in signslocation:
            return None
        else:
            lat = currentlocation[:signslocation[1]]
            lon = currentlocation[signslocation[1]:]
            correctlocation = "{0},{1}".format(lat, lon)
            global API
            url = f'https://maps.googleapis.com/maps/api/place/nearbysearch/json?key={API}&location={correctlocation}&radius={radius}'
            urlmessage = f'Server {self.name} start process url get google with location  {currentlocation}'
            print(urlmessage)
            logging.info(urlmessage)
            googlejsonresult = await self.processaiohttp(url)
            urlsuccessmessage = f'Server {self.name} get google result'
            print(urlsuccessmessage)
            logging.info(urlsuccessmessage)
            googledictresult = json.loads(googlejsonresult)
            if len(googledictresult["results"]) > boundnumber:
                googledictresult["results"] = googledictresult["results"][:boundnumber]
                googlejsonresult = json.dumps(googledictresult,indent=4)
            return googlejsonresult


    async def processaiohttp(self, url):
        async with aiohttp.ClientSession() as session:
            async with session.get(url) as resp:
                response = await resp.text() # cannot use json as TA hint code does
                return response
    #adapted from TA Hintcode Repo:https://github.com/CS131-TA-team/UCLA_CS131_CodeHelp/blob/master/Python/echo_server.py
    async def runeventloop(self):
        runmessage = f'Server {self.name} entering running event loop successfully'
        print(runmessage)
        logging.info(runmessage)

        server = await asyncio.start_server(self.processcommand, self.ip, self.port)

        startsuccessmessage = f'Server {self.name} start the sever successfully'
        print(startsuccessmessage)
        logging.info(startsuccessmessage)
        # Serve requests until Ctrl+C is pressed
        # print(f'serving on {server.sockets[0].getsockname()}')
        async with server:
            await server.serve_forever()
        finishmessage = f'Server {self.name} is about to close'
        print(finishmessage)
        logging.info(finishmessage)

        # Close the server
        server.close()

#The following main function is adapted from TA Hintcode Repo:https://github.com/CS131-TA-team/UCLA_CS131_CodeHelp/blob/master/Python/echo_server.py
def tamain():
    possiblename = ["Riley","Jaquez","Juzang","Campbell","Bernard"]
    parser = argparse.ArgumentParser('Chenda CS131 Python Proj Adapted from TA hintcode')
    parser.add_argument('server_name', type=str,
                        help='required server name input')
    args = parser.parse_args()
    inputservername = args.server_name
    if inputservername not in possiblename:
        print("Error: wrong servername, please choose from Riley Jaquez Juzang Campbell Bernard")
        exit(1)
    #ideas from discussion 1b and https://realpython.com/python-logging/
    logging.basicConfig(filename='app.log', filemode='w+',format='%(levelname)s - %(message)s',level=logging.INFO)
    global serverstats
    portnum = int(serverstats[inputservername][0])
    server = TAServer(inputservername,portnum)
    startingmessage = f'Server {inputservername} starts successfully with port number |{str(portnum)}|'
    print(startingmessage)
    logging.info(startingmessage)
    try:
        asyncio.run(server.runeventloop())
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    tamain()

