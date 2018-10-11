using System;
using System.IO.Ports;
using System.Threading;

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
                var data = ReadFromSerialPort();
                return (data & 0x80) == 0;
            }
        }

        public byte ReadData()
        {
            WriteToSerialPort(4);
            return ReadFromSerialPort();
        }

        public byte ReadStatus()
        {
            WriteToSerialPort(2);
            return ReadFromSerialPort();
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

        private byte ReadFromSerialPort()
        {
            while (serialPort.BytesToRead == 0) Thread.Sleep(1);
            return (byte)serialPort.ReadByte();
        }

        public byte[] ReadMultipleData(int length)
        {
            if (length == 0) return new byte[0];

            var data = new byte[length];
            var index = 0;
            var remaining = length;
            while (remaining > 0)
            {
                var blockLength = Math.Min(remaining, 256);
                WriteToSerialPort(6, (byte)(blockLength == 256 ? 0 : blockLength));
                while (serialPort.BytesToRead < blockLength) Thread.Sleep(1);
                serialPort.Read(data, index, blockLength);
                index += blockLength;
                remaining -= blockLength;
            }
            return data;
        }

        public void WriteMultipleData(byte[] data)
        {
            var index = 0;
            var remaining = data.Length;
            while(remaining > 0)
            {
                var blockLength = Math.Min(remaining, 256);
                WriteToSerialPort(7, (byte)(blockLength == 256 ? 0 : blockLength));
                serialPort.Write(data, index, blockLength);
                index += blockLength;
                remaining -= blockLength;
            }
        }
    }
}
