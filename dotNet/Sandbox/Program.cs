using System;
using System.Linq;
using System.Text;
using System.Threading;
using Konamiman.RookieDrive.Usb;

namespace Konamiman.RookieDrive.Sandbox
{
    class Program
    {
        static IUsbHost usb;

        static void Main(string[] args)
        {
            try
            {
                Console.SetWindowSize(Console.WindowWidth, Console.WindowHeight + 10);
                _Main(args);
            }
            catch(UsbTransferException ex)
            {
                Console.WriteLine($"*** {ex.Message}");
            }
            Console.ReadKey();
        }

        static void _Main(string[] args)
        {
            var hw = new CH376UsbHostHardware(UsbServiceProvider.GetCH376Ports());
            hw.HardwareReset();
            var diskName = hw.InitDisk();
            if (diskName == null)
                Console.WriteLine("*** No storage device detected");
            else
                Console.WriteLine("Storage device detected: " + diskName);

            dynamic diskTypeAndCapacity = hw.GetDiskTypeAndCapacity();
            Console.WriteLine($"Total size: {diskTypeAndCapacity.totalSizeMb} MB");
            Console.WriteLine($"Free size:  {diskTypeAndCapacity.freeSizeMb} MB");
            Console.WriteLine($"Filesystem: {diskTypeAndCapacity.filesystem}");
            Console.WriteLine();

            hw.InitFilesystem();
            var files = hw.EnumerateFiles("/");
            if(files.Length == 0)
            {
                Console.WriteLine("*** No files found");
            }
            else
            {
                Console.WriteLine("Files found:");
                foreach (var name in files)
                    Console.WriteLine(name);

                Console.WriteLine();
                Console.WriteLine("Files found in DSK:");
                files = hw.EnumerateFiles("DSK");
                foreach (var name in files)
                    Console.WriteLine(name);

                Console.WriteLine();
                Console.WriteLine("Contents of DSK/DRIVER.ASM:");
                Console.Write(hw.ReadFileContents("DRIVER.ASM"));
            }
            Console.ReadKey();
            return;

            /////

            var deviceWasConnected = false;
            usb = new UsbHost(new CH376UsbHostHardware(UsbServiceProvider.GetCH376Ports("90.173.150.35", 1288)));

            do
            {
                var devInfo = usb.GetConnectedDeviceInfo(1);
                if(devInfo != null && !deviceWasConnected)
                {
                    deviceWasConnected = true;
                    Console.WriteLine("Connected!");
                    PrintDeviceInfo(1);
                    PrintFddInfo(usb, 1);
                }
                else if(devInfo == null && deviceWasConnected)
                {
                    deviceWasConnected = false;
                    Console.WriteLine("Disconnected...");
                }

                Thread.Sleep(100);
                usb.UpdateDeviceConnectionStatus();
            } while (!Console.KeyAvailable);
        }

        private static void PrintDeviceInfo(byte deviceAddress)
        {
            var devInfo = usb.GetConnectedDeviceInfo(1);
            
            Console.WriteLine($"Manufacturer: {GetStringDescriptor(deviceAddress, devInfo.ManufacturerStringIndex)}");
            Console.WriteLine($"Product: {GetStringDescriptor(deviceAddress, devInfo.ProductStringIndex)}");
            Console.WriteLine("");
            Console.WriteLine($"Class: {devInfo.Class}");
            Console.WriteLine($"Subclass: {devInfo.Subclass}");
            Console.WriteLine($"Protocol: {devInfo.Protocol}");
            Console.WriteLine($"VID: {devInfo.VendorId:X2}h");
            Console.WriteLine($"PID: {devInfo.ProductId:X2}h");
            Console.WriteLine("");
            Console.WriteLine($"Endpoint 0 max packet size: {devInfo.EndpointZeroMaxPacketSize}");
            foreach (var iface in devInfo.InterfacesForCurrentConfiguration)
            {
                Console.WriteLine("");
                Console.WriteLine("Interface:");
                Console.WriteLine($"  Class: {iface.Class}");
                Console.WriteLine($"  Subclass: {iface.Subclass}");
                Console.WriteLine($"  Protocol: {iface.Protocol}");

                Console.WriteLine("");
                Console.WriteLine("  Endpoints:");
                foreach (var ep in iface.Endpoints)
                {
                    Console.WriteLine("");
                    Console.WriteLine($"    Number: 0x{ep.Number:X}");
                    Console.WriteLine($"    Direction: {ep.DataDirection}");
                    Console.WriteLine($"    Type: {ep.Type}");
                    Console.WriteLine($"    Max packet size: {ep.MaxPacketSize}");
                }
            }
        }

        private static string GetStringDescriptor(byte deviceAddress, byte stringIndex)
        {
            try
            {
                if (stringIndex == 0)
                    return "(No data)";

                var getStrSetup = new UsbSetupPacket(UsbStandardRequest.GET_DESCRIPTOR, 0x80)
                {
                    wValueH = UsbDescriptorType.STRING,
                    wValueL = stringIndex,
                    wLength = 255
                };

                var zeroStringDesc = usb.ExecuteControlInTransfer(getStrSetup, deviceAddress);
                if (zeroStringDesc.Length < 4)
                    return "(Invalid descriptor received)";

                getStrSetup.wIndexL = zeroStringDesc[2];
                getStrSetup.wIndexH = zeroStringDesc[3];

                var stringDesc = usb.ExecuteControlInTransfer(getStrSetup, deviceAddress);

                return Encoding.Unicode.GetString(stringDesc.Skip(2).ToArray());
            }
            catch(Exception ex)
            {
                return ex.Message;
            }
        }

        private static void ThrowIfError(UsbTransferResult result)
        {
            if (result.IsError)
                throw new Exception(result.TransactionResult.ToString());
        }

        private static void PrintFddInfo(IUsbHost host, int deviceNumber)
        {
            var cbi = new UsbCbiTransport(host, deviceNumber);
            var modeSenseCommand = new byte[] {
                0x5A, //opcode
                0,
                5,  //flexible disk page,
                0, 0, 0, 0,
                0, 192, //parameter list length
                0, 0, 0
            };
            var cbiResetCommand = new byte[] { 0x1D, 0x04, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };
            var readFormatCapacitiesCommand = new byte[] { 0x23, 0, 0, 0, 0, 0, 0, 0, 100, 0, 0, 0 };
            var readCommand = new byte[] { 0x28, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0 };
            var read0Command = new byte[] { 0x28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
            var startCommand = new byte[] { 0x1B, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0 };
            var inquiryCommand = new byte[] { 0x12, 0, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0 };
            var sendDiagnosticCommand = new byte[] { 0x1D, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
            var testUnitReadyCommand = new byte[] { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
            var formatCommand = new byte[]
            {
                0x04, 0x17, 0, 0, 0, 0, 0,
                0, 12, //param list length
                0, 0, 0
            };
            var formatData = new byte[]
            {
                0, 0xB0, 0, 8,  //2nd = A0 for non single track format
                0, 0, 0x0B, 0x40,   //sector count (1.44M)
                //0, 0, 0x05, 0xA0,   //sector count (720K)
                0,
                0, 2, 0 //sector size
            };

            Console.WriteLine($"\r\nDevice: {GetInquiryData(cbi, 1)}");

            //ExecuteUfiCommand(cbi, 1, modeSenseCommand, "Mode Sense", 192);

            while (true)
            {
                Console.WriteLine();

                var key = Console.ReadKey();
                if (key.Key == ConsoleKey.F)
                {
                    ExecuteUfiCommand(cbi, 1, readFormatCapacitiesCommand, "Read format capacities", 100);
                }
                else if (key.Key == ConsoleKey.M)
                {
                    ExecuteUfiCommand(cbi, 1, modeSenseCommand, "Mode sense", 192);
                }
                else if (key.Key == ConsoleKey.D)
                {
                    ExecuteUfiCommand(cbi, 1, sendDiagnosticCommand, "Send diagnostic", 192);
                }
                else if (key.Key == ConsoleKey.U)
                {
                    ExecuteUfiCommand(cbi, 1, testUnitReadyCommand, "Test unit ready", 0);
                }
                else if (key.Key == ConsoleKey.X)
                {
                    for (var side = 0; side < 2; side++)
                    {
                        for (var track = 0; track < 80; track++)
                        {
                            Console.WriteLine($"Format: track {track}, side {side}");
                            formatCommand[2] = (byte)track;
                            formatData[5] = (byte)((formatData[5] & 0xFE) | side);
                            ExecuteUfiCommand(cbi, 1, formatCommand, "Format", formatData);
                        }
                    }
                }
                else
                {
                    ExecuteUfiCommand(cbi, 1, readCommand, "Read", 512);
                }
            }
        }

        private static object GetInquiryData(UsbCbiTransport cbi, int deviceAddress)
        {
            var inquiryCommand = new byte[] { 0x12, 0, 0, 0, 36, 0, 0, 0, 0, 0, 0, 0 };
            var inquiryDataBuffer = new byte[36];

            while(true) {
                var result = cbi.ExecuteCommand(inquiryCommand, inquiryDataBuffer, 0, 36, UsbDataDirection.IN);
                if (result.SenseData[0] == 0x28 || result.SenseData[0] == 0x29)
                    continue;
                if (result.IsError || result.SenseData[0] != 0)
                {
                    return $"(error: {result.TransactionResult} - {result.SenseData[0]:X}h when getting inquiry data)";
                }
                break;
            }

            string GetString(int index, int length) => Encoding.ASCII.GetString(inquiryDataBuffer, index, length).Trim();

            return $"{GetString(8, 6)} {GetString(16, 16)} {GetString(32, 4)}";
        }

        private static UsbCbiCommandResult ExecuteUfiCommand(IUsbCbiTransport cbi, int deviceAddress, byte[] command, string name, int dataLength)
        {
            var dataBuffer = new byte[dataLength];

            var result = cbi.ExecuteCommand(command, dataBuffer, 0, dataLength, UsbDataDirection.IN);
            /*if(!result.IsError && result.SenseData == null)
            {
                Console.WriteLine("WTF??");
                return null;
            }
            else*/ if (result.IsError || result.SenseData == null || result.SenseData[0] != 0)
            {
                Console.WriteLine($"*** {name}: {result.TransactionResult}");
                if(result.SenseData != null)
                    Console.WriteLine($"Int endpoint: ASC = {result.SenseData[0]:X}h, ASCQ = {result.SenseData[1]:X}h");

                return null;
            }
            else
            {
                var data = dataBuffer.Take(result.TransferredDataCount).ToArray();
                if (data.Length == 0)
                    Console.WriteLine($"> {name}: No data");
                else
                    PrintHexDump(data);
                return result;
            }
        }

        private static UsbCbiCommandResult ExecuteUfiCommand(IUsbCbiTransport cbi, int deviceAddress, byte[] command, string name, byte[] dataToSend)
        {
            var result = cbi.ExecuteCommand(command, dataToSend, 0, dataToSend.Length, UsbDataDirection.OUT);
            if (result.IsError || result.SenseData[0] != 0)
            {
                Console.WriteLine($"*** {name}: {result.TransactionResult}");
                if (result.SenseData != null)
                    Console.WriteLine($"Int endpoint: ASC = {result.SenseData[0]:X}h, ASCQ = {result.SenseData[1]:X}h");

                return null;
            }
            else
            {
                Console.WriteLine($">>> {name}: Ok, sent {dataToSend.Length} bytes");
                return result;
            }
        }

        private static void PrintHexDump(byte[] data)
        {
            var remainingLength = data.Length;
            var dataIndex = 0;
            var baseIndexForCurrentRow = dataIndex;

            while (remainingLength > 0)
            {
                var bytesInCurrentRow = Math.Min(remainingLength, 16);
                for (int i = 0; i < bytesInCurrentRow; i++)
                {
                    Console.Write($"{data[dataIndex + baseIndexForCurrentRow + i]:X2} ");
                }
                for (int i = 0; i < bytesInCurrentRow; i++)
                {
                    var dataByte = data[dataIndex + baseIndexForCurrentRow + i];
                    if (dataByte < 32 || dataByte > 126)
                        Console.Write(".");
                    else
                        Console.Write(Encoding.ASCII.GetChars(new[] { dataByte })[0].ToString());
                }
                baseIndexForCurrentRow += bytesInCurrentRow;
                remainingLength -= bytesInCurrentRow;
                Console.WriteLine();
            }
        }
    }
}
