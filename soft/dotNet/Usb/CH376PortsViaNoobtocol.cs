using System;
using System.IO.Ports;

namespace Konamiman.RookieDrive.Usb
{
    public class CH376PortsViaNoobtocol : ICH376Ports, IDisposable
    {
        SerialPort serialPort;

        public CH376PortsViaNoobtocol(string serialPortName, int baudRate = 115200)
        {
            serialPort = new SerialPort(serialPortName, baudRate);
            serialPort.Open();
        }
        public void Dispose()
        {
            serialPort.Dispose();
        }

        public bool IntIsActive
        {
            get
            {
                WriteToSerialPort(2);
                var data = serialPort.ReadByte();
                return (data & 0x80) == 0;
            }
        }

        public byte ReadData()
        {
            WriteToSerialPort(4);
            return (byte)serialPort.ReadByte();
        }

        public void WriteCommand(byte command)
        {
            WriteToSerialPort(1, command);
        }

        public void WriteData(byte data)
        {
            WriteToSerialPort(3, data);
        }

        private void WriteToSerialPort(params byte[] data)
        {
            serialPort.Write(data, 0, data.Length);
        }
    }
}
