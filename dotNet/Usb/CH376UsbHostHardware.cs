using System;
using System.Threading;
using System.Linq;
using System.Text;
using System.Dynamic;
using System.Collections.Generic;

namespace Konamiman.RookieDrive.Usb
{
    public class CH376UsbHostHardware : IUsbHostHardware, IUsbHardwareShortcuts
    {
        const byte RESET_ALL = 0x05;
        const byte WR_HOST_DATA = 0x2C;
        const byte RD_USB_DATA0 = 0x27;
        const byte ISSUE_TKN_X = 0x4E;
        const byte GET_STATUS = 0x22;
        const byte SET_USB_ADDR = 0x13;
        const byte SET_USB_MODE = 0x15;
        const byte GET_DESCR = 0x46;

        const byte PID_SETUP = 0x0D;
        const byte PID_IN = 0x09;
        const byte PID_OUT = 0x01;

        const byte INT_SUCCESS = 0x14;
        const byte INT_CONNECT = 0x15;
        const byte INT_DISCONNECT = 0x16;
        const byte USB_INT_BUF_OVER = 0x17;
        const byte CMD_CLR_STALL = 0x41;
        const byte CMD_RET_SUCCESS = 0x51;
        const byte CMD_RET_ABORT = 0x5F;

        const byte CMD_GET_IC_VER = 0x01;
        const byte CMD_READ_VAR8 = 0x0A;
        const byte CMD_WRITE_VAR8 = 0x0B;
        const byte CMD_READ_VAR32 = 0x0C;
        const byte CMD_WRITE_VAR32 = 0x0D;
        const byte CMD_TEST_CONNECT = 0x16;
        const byte CMD_DISK_CONNECT = 0x30;
        const byte CMD_DISK_MOUNT = 0x31;
        const byte CMD_DISK_CAPACITY = 0x3E;
        const byte CMD_DISK_QUERY = 0x3F;
        const byte CMD_SET_FILE_NAME = 0x2F;
        const byte CMD_FILE_OPEN = 0x32;
        const byte CMD_FILE_ENUM_GO = 0x33;
        const byte CMD_FILE_CLOSE = 0x36;
        const byte CMD_BYTE_LOCATE = 0x39;
        const byte CMD_BYTE_READ = 0x3A;
        const byte CMD_BYTE_RD_GO = 0x3B;
        const byte CMD_WR_REQ_DATA = 0x2D;
        const byte CMD_BYTE_WRITE = 0x3C;
        const byte CMD_BYTE_WRITE_GO = 0x3D;
        const byte CMD_FILE_CREATE = 0x34;

        private readonly ICH376Ports ch;
        private static readonly byte[] noData = new byte[0];

        public CH376UsbHostHardware(ICH376Ports ch376Ports)
        {
            this.ch = ch376Ports;

            HardwareReset();
            deviceIsConnected = false;
            SetHostWithoutSofMode();
        }

        bool deviceIsConnected = false;

        public void HardwareReset()
        {
            ch.WriteCommand(RESET_ALL);
            Thread.Sleep(50);
            SetHostWithoutSofMode();
        }

        private UsbPacketResult BusResetAndSetHostWithSofMode()
        {
            var result = SetUsbMode(7);
            if (result != UsbPacketResult.Ok)
                return result;

            Thread.Sleep(35);

            return SetUsbMode(6);
        }

        private UsbPacketResult SetUsbMode(byte mode)
        {
            ch.WriteCommand(SET_USB_MODE);
            ch.WriteData(mode);
            for(int i=0; i<50; i++)
            {
                if (ch.ReadData() == CMD_RET_SUCCESS)
                    return UsbPacketResult.Ok;

                Thread.Sleep(1);
            }

            return UsbPacketResult.OtherError;
        }

        private void SetHostWithoutSofMode()
        {
            ch.WriteCommand(SET_USB_MODE);
            ch.WriteData(5);
        }

        public UsbDeviceConnectionStatus CheckConnectionStatus()
        {
            if (ch.IntIsActive)
            {
                ch.WriteCommand(GET_STATUS);
                var status = ch.ReadData();

                if (status == INT_CONNECT)
                {
                    deviceIsConnected = true;
                    return BusResetAndSetHostWithSofMode() == UsbPacketResult.Ok ?
                        UsbDeviceConnectionStatus.Changed :
                        UsbDeviceConnectionStatus.Error;
                }
                else if (status == INT_DISCONNECT)
                {
                    deviceIsConnected = false;
                    SetHostWithoutSofMode();
                    return UsbDeviceConnectionStatus.NotConnected;
                }
            }

            return deviceIsConnected ? UsbDeviceConnectionStatus.Connected : UsbDeviceConnectionStatus.NotConnected;
        }

        public UsbTransferResult ExecuteControlTransfer(UsbSetupPacket setupPacket, byte[] dataBuffer, int dataBufferIndex, int deviceAddress, int endpointPacketSize, int endpointNumber = 0)
        {
            var requestedDataLength = (int)setupPacket.wLength;
            var remainingDataLength = requestedDataLength;
            UsbPacketResult result;

            SetTargetDeviceAddress(deviceAddress);

            //Setup

            WriteUsbData(setupPacket.ToByteArray());
            IssueToken(endpointNumber, PID_SETUP, 0, 0);
            if ((result = WaitAndGetResult()) != UsbPacketResult.Ok)
                return new UsbTransferResult(result);

            //Data

            var dataTransferResult = setupPacket.DataDirection == UsbDataDirection.IN ?
                ExecuteDataInTransfer(dataBuffer, dataBufferIndex, requestedDataLength, deviceAddress, 0, endpointPacketSize, 1) :
                ExecuteDataOutTransfer(dataBuffer, dataBufferIndex, requestedDataLength, deviceAddress, 0, endpointPacketSize, 1);

            if (dataTransferResult.IsError)
                return dataTransferResult;

            //Status

            if(setupPacket.DataDirection == UsbDataDirection.OUT || requestedDataLength == 0)
                result = RepeatWhileNak(() => {
                    IssueToken(endpointNumber, PID_IN, 1, 0);
                    ReadUsbData(null);
                });
            else
                result = RepeatWhileNak(() => {
                    WriteUsbData(noData);
                    IssueToken(endpointNumber, PID_OUT, 0, 1);
                });

            if (result != UsbPacketResult.Ok)
                return new UsbTransferResult(result);

            return dataTransferResult;
        }

        private UsbPacketResult RepeatWhileNak(Action action)
        {
            UsbPacketResult result;
            do
            {
                action();
                result = WaitAndGetResult();
                if (result == UsbPacketResult.Nak)
                    Thread.Sleep(1);
            }
            while (result == UsbPacketResult.Nak);
            return result;
        }

        private void SetTargetDeviceAddress(int deviceAddress)
        {
            ch.WriteCommand(SET_USB_ADDR);
            ch.WriteData((byte)deviceAddress);
        }

        private void WriteUsbData(byte[] data, int index = 0, int? length = null)
        {
            length = length ?? data.Length - index;
            ch.WriteCommand(WR_HOST_DATA);
            ch.WriteData((byte)length);
            for(var i = 0; i < length; i++)
                ch.WriteData(data[index + i]);
        }

        int ReadUsbData(byte[] data, int index = 0)
        {
            ch.WriteCommand(RD_USB_DATA0);
            var length = ch.ReadData();

            var data2 = ch.ReadMultipleData(length);
            if (data != null)
                Array.Copy(data2, 0, data, index, length);

            return length;
        }

        void IssueToken(int endpointNumber, byte pid, int intToggle, int outToggle)
        {
            ch.WriteCommand(ISSUE_TKN_X);
            ch.WriteData((byte)(intToggle << 7 | outToggle << 6));
            ch.WriteData((byte)(endpointNumber << 4 | pid));
        }

        private UsbPacketResult WaitAndGetResult()
        {
            while (!ch.IntIsActive)
                Thread.Sleep(1);

            ch.WriteCommand(GET_STATUS);
            var result = ch.ReadData();

            switch(result)
            {
                case CMD_RET_SUCCESS:
                    return UsbPacketResult.Ok;
                case INT_SUCCESS:
                    return UsbPacketResult.Ok;
                case INT_DISCONNECT:
                    deviceIsConnected = false;
                    SetHostWithoutSofMode();
                    return UsbPacketResult.NoDeviceConnected;
                case USB_INT_BUF_OVER:
                    return UsbPacketResult.DataError;
            }

            var result2 = result & 0x2F;

            switch(result2)
            {
                case 0x2A:
                    return UsbPacketResult.Nak;
                case 0x2E:
                    return UsbPacketResult.Stall;
            }

            result2 &= 0x23;

            if (result2 == 0x20)
                return UsbPacketResult.Timeout;

            if(result >= 0x14 && Enum.IsDefined(typeof(UsbPacketResult), (int)result)) {
                return (UsbPacketResult)result;
            }

            throw new Exception($"Unexpected value from GET_STATUS: 0x{result:X}");
        }

        public UsbTransferResult ExecuteDataInTransfer(byte[] dataBuffer, int dataBufferIndex, int dataLength, int deviceAddress, int endpointNumber, int endpointPacketSize, int toggleBit)
        {
            var remainingDataLength = dataLength;
            UsbPacketResult result;

            SetTargetDeviceAddress(deviceAddress);

            while (remainingDataLength > 0)
            {
                result = RepeatWhileNak(() => IssueToken(endpointNumber, PID_IN, toggleBit, 0));
                if (result != UsbPacketResult.Ok)
                    return new UsbTransferResult(result, toggleBit);

                toggleBit = toggleBit ^ 1;
                var amountRead = ReadUsbData(dataBuffer, dataBufferIndex);
                dataBufferIndex += amountRead;
                remainingDataLength -= amountRead;

                if (amountRead < endpointPacketSize)
                    break;
            }

            return new UsbTransferResult(dataLength - remainingDataLength, toggleBit);
        }

        public UsbTransferResult ExecuteDataOutTransfer(byte[] dataBuffer, int dataBufferIndex, int dataLength, int deviceAddress, int endpointNumber, int endpointPacketSize, int toggleBit)
        {
            var remainingDataLength = dataLength;
            UsbPacketResult result;

            SetTargetDeviceAddress(deviceAddress);

            while (remainingDataLength > 0)
            {
                var amountWritten = Math.Min(endpointPacketSize, remainingDataLength);
                WriteUsbData(dataBuffer, dataBufferIndex, amountWritten);
                result = RepeatWhileNak(() => IssueToken(endpointNumber, PID_OUT, 0, toggleBit));
                if (result != UsbPacketResult.Ok)
                    return new UsbTransferResult(result, toggleBit);

                toggleBit = toggleBit ^ 1;
                dataBufferIndex += amountWritten;
                remainingDataLength -= amountWritten;
            }

            return new UsbTransferResult(dataLength, toggleBit);
        }

        public UsbTransferResult GetDescriptor(int deviceAddress, byte descriptorType, byte descriptorIndex, int languageId, out byte[] descriptorBytes)
        {
            SetTargetDeviceAddress(deviceAddress);

            descriptorBytes = null;
            if(
                (descriptorType != UsbDescriptorType.DEVICE && 
                descriptorType != UsbDescriptorType.CONFIGURATION) ||
                descriptorIndex != 0 ||
                languageId != 0)
            {
                return new UsbTransferResult(UsbPacketResult.NotImplemented);
            }

            ch.WriteCommand(GET_DESCR);
            ch.WriteCommand(descriptorType);
            var result = WaitAndGetResult();
            if (result == UsbPacketResult.DataError)
                return new UsbTransferResult(UsbPacketResult.NotImplemented);
            else if (result != UsbPacketResult.Ok)
                return new UsbTransferResult(result);

            descriptorBytes = new byte[64];
            var length = ReadUsbData(descriptorBytes);
            descriptorBytes = descriptorBytes.Take(length).ToArray();
            return new UsbTransferResult(length, 0);
        }

        public UsbTransferResult ClearEndpointHalt(int deviceAddress, byte endpointNumber)
        {
            SetTargetDeviceAddress(deviceAddress);

            ch.WriteCommand(CMD_CLR_STALL);
            ch.WriteData(endpointNumber);
            var result = WaitAndGetResult();
            return new UsbTransferResult(result);
        }

        public string InitDisk()
        {
            ch.WriteCommand(CMD_TEST_CONNECT);
            byte status;
            do
            {
                status = ch.ReadStatus();
            } while (status == 0);
            var result = (UsbPacketResult)(status & 0x7F); // WaitAndGetResult();
            if (result == UsbPacketResult.NoDeviceConnected)
                return "*** No device connected";
            
            BusResetAndSetHostWithSofMode();
            ch.WriteCommand(CMD_DISK_MOUNT);
            result = WaitAndGetResult();
            if (result != UsbPacketResult.Ok)
                return "*** No proper storage device connected";

            var data = new byte[36];
            ReadUsbData(data, 0);
            return Encoding.ASCII.GetString(data.Skip(8).ToArray());
        }

        public object GetDiskTypeAndCapacity()
        {
            byte d;
            ch.WriteCommand(CMD_GET_IC_VER);
            d = ch.ReadData();
            if (d < 0x43)
            {
                // This is supposed to be a fix for bad handling of FAT32
                // columes in older versions of the chip
                ch.WriteCommand(CMD_READ_VAR8);
                ch.WriteData(0x28);  //VAR_DISK_STATUS
                d = ch.ReadData();
                if (d >= 0x10)  //DEF_DISK_READY
                {
                    ch.WriteCommand(CMD_WRITE_VAR8);
                    ch.WriteData(0x28);
                    ch.WriteData(3); //DEF_DISK_MOUNTED
                }
            }
                

            ch.WriteCommand(CMD_DISK_QUERY);
            var result = WaitAndGetResult();
            if (result != UsbPacketResult.Ok)
                return null;

            var data = new byte[9];
            ReadUsbData(data, 0);
            var totalSectorsCount = BitConverter.ToInt32(data, 0);
            var freeSectorsCount = BitConverter.ToInt32(data, 4);
            var filesystemTypeByte = data[8];

            dynamic r = new ExpandoObject();
            r.totalSizeMb = totalSectorsCount / 2048;
            r.freeSizeMb = freeSectorsCount / 2048;
            r.filesystem =
                    filesystemTypeByte == 1 ? "FAT12" :
                    filesystemTypeByte == 2 ? "FAT16" :
                    filesystemTypeByte == 3 ? "FAT32" :
                    $"Unknown ({filesystemTypeByte})";

            return r;
        }

        public void InitFilesystem()
        {
            return;
            FixSetFilename();
            ch.WriteCommand(CMD_SET_FILE_NAME);
            ch.WriteData(0);
            ch.WriteCommand(CMD_FILE_OPEN);
        }

        private UsbPacketResult DoFileOpen(string name)
        {
            FixSetFilename();
            ch.WriteCommand(CMD_SET_FILE_NAME);
            ch.WriteMultipleData(Encoding.ASCII.GetBytes(name + "\0"));

            if (name[0] == '/')
            {
                ch.WriteCommand(CMD_WRITE_VAR32);
                ch.WriteData(0x64); //VAR_CURRENT_CLUST
                ch.WriteData(0);
                ch.WriteData(0);
                ch.WriteData(0);
                ch.WriteData(0);
            }
            
            ch.WriteCommand(CMD_FILE_OPEN);
            return WaitAndGetResult();
        }

        public string[] EnumerateFiles(string searchPath = "/")
        {
            var result = DoFileOpen(searchPath);
            if (result != UsbPacketResult.ERR_OPEN_DIR)
                return new[] { $"*** Error opening directory: {result}" };

            result = DoFileOpen("*");

            var data = new byte[32];
            var names = new List<string>();
            while (result == UsbPacketResult.USB_INT_DISK_READ)
            {
                ReadUsbData(data);
                
                var name = Encoding.ASCII.GetString(data, 0, 8).Trim();
                var ext = Encoding.ASCII.GetString(data, 8, 3).Trim();
                if (ext != "")
                    name = $"{name}.{ext}";
                if ((data[11] & 0x10) == 0x10)
                    name += "/";

                names.Add(name);

                ch.WriteCommand(CMD_FILE_ENUM_GO);
                result = WaitAndGetResult();
            }

            return names.ToArray();
        }

        public string ReadFileContents(string filename)
        {
            int count;
            UsbPacketResult result;
            var data = new byte[65535];

            result = DoFileOpen(filename);
            if (result != UsbPacketResult.Ok)
                return "*** Error opening file: " + result.ToString();

            var sb = new StringBuilder();

            while (true)
            {
                ch.WriteCommand(CMD_BYTE_READ);
                ch.WriteData(0xFF);
                ch.WriteData(0xFF); //Request 65535 bytes
                result = WaitAndGetResult();
                if (result == UsbPacketResult.Ok)
                    return sb.ToString();
                else if (result != UsbPacketResult.USB_INT_DISK_READ)
                    return "*** Error reading file: " + result.ToString();

                do
                {
                    count = ReadUsbData(data);
                    sb.Append(Encoding.ASCII.GetString(data, 0, count));
                    ch.WriteCommand(CMD_BYTE_RD_GO);
                    result = WaitAndGetResult();
                }
                while (result == UsbPacketResult.USB_INT_DISK_READ);
            }
        }

        public string WriteFileContents(string filename, string contents)
        {
            UsbPacketResult result;

            result = DoFileOpen(filename);
            if(result == UsbPacketResult.ERR_MISS_FILE)
            {
                Console.WriteLine(">>> File doesn't exist, creating");
                ch.WriteCommand(CMD_FILE_CREATE);
                result = WaitAndGetResult();
                if (result != UsbPacketResult.Ok)
                {
                    return "*** Error creating file: received " + result.ToString();
                }
            }
            if (result != UsbPacketResult.Ok)
                return "*** Error opening file: " + result.ToString();

            var bytesToWrite = Encoding.ASCII.GetBytes(contents);

            ch.WriteCommand(CMD_BYTE_WRITE);
            ch.WriteData((byte)(bytesToWrite.Length & 0xFF));
            ch.WriteData((byte)(bytesToWrite.Length >> 8));
            result = WaitAndGetResult();

            while(result != UsbPacketResult.Ok)
            {
                if(result != UsbPacketResult.USB_INT_DISK_WRITE)
                {
                    return "*** Error writing file: received " + result.ToString();
                }

                ch.WriteCommand(CMD_WR_REQ_DATA);
                var nextChunkSize = ch.ReadData();
                var chunk = bytesToWrite.Take(nextChunkSize).ToArray();
                //For some reason CH376PortsViaNoobtocol.WriteMultipleData doesn't work for 255 bytes...
                for (int i = 0; i < chunk.Length; i++) ch.WriteData(chunk[i]);
                //ch.WriteMultipleData(chunk);

                bytesToWrite = bytesToWrite.Skip(nextChunkSize).ToArray();

                ch.WriteCommand(CMD_BYTE_WRITE_GO);
                result = WaitAndGetResult();
            }

            ch.WriteCommand(CMD_BYTE_WRITE);
            ch.WriteData(0);
            ch.WriteData(0);
            result = WaitAndGetResult();
            if(result != UsbPacketResult.Ok)
            {
                return "*** Error updating file dir entry after write: " + result.ToString();
            }

            ch.WriteCommand(CMD_FILE_CLOSE);
            ch.WriteData(1);
            WaitAndGetResult();
            return ">>> Write ok!";
        }

        public bool ChangeDir(string dir)
        {
            var result = DoFileOpen(dir);
            return result == UsbPacketResult.ERR_OPEN_DIR;
        }

        private void FixSetFilename()
        {
            /*ch.WriteCommand(CMD_FILE_CLOSE);
            ch.WriteData(0);
            WaitAndGetResult();*/

            byte d;
            ch.WriteCommand(CMD_GET_IC_VER);
            d = ch.ReadData();
            if (d >= 0x43)
                return;

            ch.WriteCommand(CMD_READ_VAR8);
            ch.WriteData(0x2B);  //VAR_DISK_STATUS
            d = ch.ReadData();
            if (d >= 0x10)  //DEF_DISK_READY
                return;

            ch.WriteCommand(CMD_SET_FILE_NAME);
            ch.WriteData(0);
            ch.WriteCommand(CMD_FILE_OPEN);
            var result = WaitAndGetResult();
            if (result != UsbPacketResult.Ok)
                return;

            ch.WriteCommand(CMD_READ_VAR8);
            ch.WriteData(0xCF);
            d = ch.ReadData();
            if (d == 0)
                return;

            WriteFix(0x4C, d);
            WriteFix(0x50, d);
            ch.WriteCommand(CMD_WRITE_VAR32);
            ch.WriteData(0x70);
            ch.WriteData(0);
            ch.WriteData(0);
            ch.WriteData(0);
            ch.WriteData(0);
        }

        private void WriteFix(byte address, byte value)
        {
            ch.WriteCommand(CMD_READ_VAR32);
            ch.WriteData(address);
            uint value32 = (uint)(ch.ReadData() + ch.ReadData() << 8 + ch.ReadData() << 16 + ch.ReadData() << 24);
            value32 += (uint)(value << 8);
            ch.WriteCommand(CMD_WRITE_VAR32);
            ch.WriteData(address);
            ch.WriteData((byte)(value32 & 0xFF));
            ch.WriteData((byte)((value32 >> 8) & 0xFF));
            ch.WriteData((byte)((value32 >> 16) & 0xFF));
            ch.WriteData((byte)((value32 >> 24) & 0xFF));
        }
    }
}
