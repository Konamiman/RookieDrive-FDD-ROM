using System;
using System.Linq;
using Konamiman.Opc.ClientLibrary;

namespace Konamiman.RookieDrive.Usb
{
    public class CH376PortsViaOpc : ICH376Ports
    {
        byte[] DataBuffer = new byte[64];

        const byte dataPort = 0x20;
        const byte commandPort = 0x21;

        private OpcClient opc;

        public CH376PortsViaOpc(string serverIp, int serverPort)
        {
            var t = new TcpTransport(serverIp, serverPort);
            this.opc = new OpcClient(t);
            t.Connect();
            var x = opc.Ping(1);
        }

        public bool IntIsActive => (ReadStatus() & 0x80) == 0;

        public byte ReadData()
        {
            opc.ReadFromPort(dataPort, DataBuffer, 0, 1, false);
            return DataBuffer[0];
        }

        public byte[] ReadMultipleData(int length)
        {
            opc.ReadFromPort(dataPort, DataBuffer, 0, length, false);
            return DataBuffer.Take(length).ToArray();
        }

        public byte ReadStatus()
        {
            opc.ReadFromPort(commandPort, DataBuffer, 0, 1, false);
            return DataBuffer[0];
        }

        public void WriteCommand(byte command)
        {
            DataBuffer[0] = command;
            opc.WriteToPort(commandPort, DataBuffer, 0, 1, false);
        }

        public void WriteData(byte data)
        {
            DataBuffer[0] = data;
            opc.WriteToPort(dataPort, DataBuffer, 0, 1, false);
        }
    }
}
