using Konamiman.NestorMSX;
using Konamiman.NestorMSX.Hardware;
using Konamiman.NestorMSX.Memories;
using Konamiman.NestorMSX.Misc;
using Konamiman.RookieDrive.Usb;
using Konamiman.Z80dotNet;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;

namespace Konamiman.RookieDrive.NestorMsxPlugin
{
    [NestorMSXPlugin("RookieDrive FDD")]
    public class RookieDriveFddPlugin
    {
        private IDictionary<ushort, Action> kernelRoutines;
        private ushort addressOfCallInihrd;
        private ushort addressOfCallDrives;
        private readonly SlotNumber slotNumber;
        private readonly string kernelFilePath;
        private readonly IZ80Processor z80;
        private readonly IExternallyControlledSlotsSystem memory;
        private readonly byte[] kernelContents;
        private readonly IUsbCbiTransport cbi;
        private byte[] dpb;

        public RookieDriveFddPlugin(PluginContext context, IDictionary<string, object> pluginConfig)
        {
            kernelRoutines = new Dictionary<ushort, Action>
            {
                { 0x4010, DSKIO },
                { 0x4013, () => DSKCHG_GETDPB(true) },
                { 0x4016, () => DSKCHG_GETDPB(false) },
                { 0x4019, CHOICE },
                { 0x401C, DSKFMT },
                { 0x401F, MTOFF  }
            };

            addressOfCallInihrd = pluginConfig.GetValueOrDefault<ushort>("addressOfCallInihrd", 0x176F);
            addressOfCallDrives = pluginConfig.GetValueOrDefault<ushort>("addressOfCallDrives", 0x1850);

            this.slotNumber = new SlotNumber(pluginConfig.GetValue<byte>("NestorMSX.slotNumber"));
            this.kernelFilePath = pluginConfig.GetMachineFilePath(pluginConfig.GetValueOrDefault("kernelFile", "MsxDosKernel.rom"));

            this.z80 = context.Cpu;
            this.memory = context.SlotsSystem;

            z80.BeforeInstructionFetch += (sender, args) => BeforeZ80InstructionFetch(z80.Registers.PC);

            this.kernelContents = File.ReadAllBytes(kernelFilePath);
            ValidateKernelFileContents(kernelContents);

            cbi = new UsbCbiTransport(new UsbHost(new CH376UsbHostHardware(new CH376PortsViaNoobtocol("COM4"))), 1);
        }

        private void ValidateKernelFileContents(byte[] kernelFileContents)
        {
            if (kernelFileContents.Length != 16 * 1024)
                throw new ConfigurationException(
                    "Invalid kernel file: a MSX-DOS kernel always has a size of exactly 16K. If you want to use MSX-DOS 2, configure a standalone MSX-DOS 2.20 kernel in ahother slot (with memory type Ascii16).");
        }

        private void BeforeZ80InstructionFetch(ushort instructionAddress)
        {
            if (memory.GetCurrentSlot(1) != slotNumber)
                return;

            if (kernelRoutines.ContainsKey(z80.Registers.PC))
            {
                var routine = kernelRoutines[z80.Registers.PC];
                routine();
                z80.ExecuteRet();
            }
        }

        public IMemory GetMemory()
        {
            if (addressOfCallInihrd != 0)
            {
                kernelContents[addressOfCallInihrd] = 0; //Patch call to INIHRD with NOPs
                kernelContents[addressOfCallInihrd + 1] = 0;
                kernelContents[addressOfCallInihrd + 2] = 0;
            }

            if (addressOfCallDrives != 0)
            {
                kernelContents[addressOfCallDrives] = 0x2E; //Patch call to DRIVES with LD L,drives
                kernelContents[addressOfCallDrives + 1] = 1;
                kernelContents[addressOfCallDrives + 2] = 0;
            }

            return new PlainRom(kernelContents, 1);
        }

        void DSKIO()
        {
            var driveNumber = z80.Registers.A;
            var numberOfSectors = z80.Registers.B;
            var memoryAddress = z80.Registers.HL.ToUShort();
            var sectorNumber = (int)z80.Registers.DE.ToUShort();
            bool isWrite = z80.Registers.CF;
            z80.Registers.CF = 1;

            if (driveNumber != 0)
            {
                z80.Registers.A = 2; //not ready
                return;
            }

            if (isWrite)
            {
                z80.Registers.A = 0; //Write protected
                return;
            }

            Debug.WriteLine($"--- Read sector: {sectorNumber}, count: {numberOfSectors}, to: {memoryAddress:X4}h");
            //try
            //{
                var sectorData = ReadSectors(sectorNumber, numberOfSectors, out byte errorCode);
                if (errorCode == 0)
                {
                    z80.Registers.A = 0;
                    SetMemoryContents(memoryAddress, sectorData);
                }
                else
                {
                    z80.Registers.A = errorCode;
                    z80.Registers.B = 0;
                }
            //}
            //catch (Exception ex)
            //{
            //    Debug.WriteLine($"*** ({ex.GetType().Name}) {ex.Message}");
            //    z80.Registers.B = 0;
            //    z80.Registers.A = 12;
            //}

            z80.Registers.CF = (z80.Registers.A != 0);
        }

        private readonly byte[] requestSenseCommand = new byte[] { 3, 0, 0, 0, 14, 0, 0, 0, 0, 0, 0, 0 };
        private byte[] ReadSectors(int sectorNumber, int numberOfSectors, out byte errorCode)
        {
            errorCode = 0;
            var readSectorCommand = new byte[] {
                0x28,
                0,
                0, 0, ((short)sectorNumber).GetHighByte(), ((short)sectorNumber).GetLowByte(),
                0,
                0, (byte)numberOfSectors,
                0, 0, 0 };
            var data = new byte[numberOfSectors * 512];
            do
            {
                var result = cbi.ExecuteCommand(readSectorCommand, data, 0, data.Length, UsbDataDirection.IN);
                if (!result.IsError && result.SenseData?[0] == 0)
                    return data;

                result = cbi.ExecuteCommand(requestSenseCommand, data, 0, 14, UsbDataDirection.IN);
                if (result.IsError)
                {
                    Debug.WriteLine($"*** Error when executing Request Sense: {result.TransactionResult}");
                    errorCode = 12;
                    return null;
                }

                var asc = data[12];
                Debug.WriteLine($"!!! ASC: {asc:X2}h, ASCQ: {data[13]:X2}h");

                if (asc == 0x28) dpb = null;

                if (asc != 0x28 && asc != 0x29)
                {
                    errorCode = DskioErrorCodeFromAsc(asc);
                    return null;
                }
                Thread.Sleep(100);
            } while (true);
        }

        byte DskioErrorCodeFromAsc(byte asc)
        {
            switch (asc)
            {
                case 0x27:
                    return 0;   //Write protected
                case 0x3A:
                    return 2;   //Not ready
                case 0x10:
                    return 4;   //CRC error
                case 0x02:
                    return 6;   //Seek error
                case 0x03:
                    return 10;  //Write fault
                default:
                    return 12;  //Other error
            }
        }

        protected void SetMemoryContents(int memoryAddress, byte[] contents)
        {
            for (var i = 0; i < contents.Length; i++)
                memory[memoryAddress + i] = contents[i];
        }

        void DSKCHG_GETDPB(bool checkFileChanged)
        {
            var driveNumber = z80.Registers.A;

            z80.Registers.CF = 1;

            if (driveNumber != 0)
            {
                z80.Registers.A = 2;
                return;
            }

            z80.Registers.A = 0;

            var diskChanged = false;
            if (checkFileChanged)
            {
                diskChanged = CheckDiskChanged(out byte errorCode);
                if (errorCode != 0)
                {
                    z80.Registers.A = errorCode;
                    z80.Registers.CF = 1;
                    return;
                }
                z80.Registers.B = (byte)(diskChanged ? -1 : 1);
            }

            if (diskChanged || dpb == null)
            {
                dpb = GenerateDpb(out byte errorCode);
                if (errorCode != 0)
                {
                    z80.Registers.A = errorCode;
                    z80.Registers.CF = 1;
                    return;
                }
            }

            memory.SetContents(z80.Registers.HL + 1, dpb);

            z80.Registers.CF = 0;
        }

        private readonly byte[] modeSenseCommand = new byte[] {
            0x5A, //opcode
            0,
            5,  //flexible disk page,
            0, 0, 0, 0,
            0, 1, //parameter list length
            0, 0, 0};

        bool CheckDiskChanged(out byte errorCode)
        {
            var changed = _CheckDiskChanged(out errorCode);
            Debug.WriteLine($"--- Check disk changed: {changed}, error = {errorCode}");
            return changed;
        }

        bool _CheckDiskChanged(out byte errorCode)
        {
            errorCode = 0;

            var data = new byte[15];
            while (true)
            {
                var result = cbi.ExecuteCommand(modeSenseCommand, data, 0, 1, UsbDataDirection.IN);
                if (!result.IsError && result.SenseData?[0] == 0)
                    return false;

                result = cbi.ExecuteCommand(requestSenseCommand, data, 0, 14, UsbDataDirection.IN);
                if (result.IsError)
                {
                    Debug.WriteLine($"*** Error when executing Request Sense: {result.TransactionResult}");
                    errorCode = 12;
                    return false;
                }

                var asc = data[12];
                Debug.WriteLine($"!!! ASC: {asc:X2}h, ASCQ: {data[13]:X2h}");
                if (asc == 0x28)
                    return true;
                else if (asc != 0x29)
                {
                    errorCode = DskioErrorCodeFromAsc(asc);
                    return false;
                }
            }
        }

        private byte[] GenerateDpb(out byte errorCode)
        {
            try
            {
                return GenerateDpbCore(out errorCode);
            }
            catch
            {
                errorCode = 12;
                return null;
            }
        }

        private byte[] GenerateDpbCore(out byte errorCode)
        {
            var sector0 = ReadSectors(0, 1, out errorCode);
            if (errorCode != 0)
                return null;

            var maxSectorNumber = 2880 - 1; //!!!

            var dpb = new byte[18];

            dpb[0] = sector0[21]; //media descriptor
            dpb[1] = 0; //sector size, low
            dpb[2] = 2; //sector size, high
            dpb[3] = 15; //dirsmsk: (sector size/32)-1
            dpb[4] = 4; //dirshift: 1s in dirmsk
            var sectorsPerCluster = sector0[13];
            dpb[5] = (byte)(sectorsPerCluster - 1); //clusmsk
            dpb[6] = (byte)(Math.Log(sectorsPerCluster, 2) + 1); //(1s in clusmsk) + 1
            var reservedSectors = NumberUtils.CreateUshort(sector0[14], sector0[15]);
            var firstFatSectorNumber = reservedSectors;
            dpb[7] = firstFatSectorNumber.GetLowByte();
            dpb[8] = firstFatSectorNumber.GetHighByte();
            var numberOfFats = sector0[16];
            dpb[9] = numberOfFats;
            var rootDirectoryEntries = NumberUtils.CreateUshort(sector0[17], sector0[18]);
            dpb[10] = (byte)(rootDirectoryEntries > 254 ? 254 : rootDirectoryEntries);
            var sectorsPerFat = NumberUtils.CreateUshort(sector0[22], sector0[23]);
            var rootDirectorySectors = rootDirectoryEntries / 16;
            var fatSectors = numberOfFats * sectorsPerFat;
            var firstDataSectorNumber = (ushort)(reservedSectors + fatSectors + rootDirectorySectors);
            dpb[11] = firstDataSectorNumber.GetLowByte();
            dpb[12] = firstDataSectorNumber.GetHighByte();
            var numberOfDataSectors = (maxSectorNumber + 1) - firstDataSectorNumber;
            var clusterCount = numberOfDataSectors / sectorsPerCluster;
            var maxClusterNumber = (ushort)(clusterCount + 1); //Note that the first cluster number is 2
            dpb[13] = maxClusterNumber.GetLowByte();
            dpb[14] = maxClusterNumber.GetHighByte();
            dpb[15] = (byte)sectorsPerFat;
            var firstDirectorySector = (ushort)(reservedSectors + fatSectors);
            dpb[16] = firstDirectorySector.GetLowByte();
            dpb[17] = firstDirectorySector.GetHighByte();

            return dpb;
        }

        void CHOICE()
        {
            z80.Registers.HL = 0;
        }

        void DSKFMT()
        {
            z80.Registers.A = 16;
            z80.Registers.CF = 1;
        }

        void MTOFF()
        {
        }
    }
}
