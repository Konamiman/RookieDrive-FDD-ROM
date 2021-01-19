using Konamiman.NestorMSX;
using Konamiman.RookieDrive.Usb;
using System.Collections.Generic;
using Konamiman.Z80dotNet;
using System.Diagnostics;
using Konamiman.NestorMSX.Hardware;
using System;
using System.IO;
using System.Linq;

namespace Konamiman.RookieDrive.NestorMsxPlugin
{
    [NestorMSXPlugin("RookieDrive ports")]
    public class RookieDrivePortsPlugin
    {
        const byte CMD_RD_USB_DATA0 = 0x27;
        const byte CMD_WR_HOST_DATA = 0x2C;

        private readonly ICH376Ports chPorts;
        private byte[] multiDataTransferBuffer;
        public int multiDataTransferPointer;
        public int multiDataTransferRemaining = 0;
        public bool waitingMultiDataTransferLength = false;
        private readonly IZ80Processor cpu;
        private bool dskioCalled = false;
        private bool dskchgCalled = false;
        private ushort returnAddress;
        private IExternallyControlledSlotsSystem slots;
        private bool dataInTransfer = false;
        private readonly IDictionary<string, ushort> symbolsByName = new Dictionary<string, ushort>();
        private readonly Stack<ushort> trackedCallsStack = new Stack<ushort>();
        private readonly Stack<string> trackedCallsStackSymbols = new Stack<string>();
        private readonly Dictionary<ushort, string> addressesToLog;
        private string indentation = "";

        private readonly string[] symbolsToLog = new[] {
            "DSKIO",
            "DSKCHG",
            "USB_DATA_IN_TRANSFER",
            "USB_CONTROL_TRANSFER",
            "HW_CONTROL_TRANSFER",
            //"HW_DATA_IN_TRANSFER",
            //"USB_EXECUTE_CBI_WITH_RETRY",
            "USB_EXECUTE_CBI",
            "CH_READ_DATA",
            "_USB_EXECUTE_CBI_CORE"
        };

        public RookieDrivePortsPlugin(PluginContext context, IDictionary<string, object> pluginConfig)
        {
            context.Cpu.MemoryAccess += Cpu_MemoryAccess;
            chPorts = new CH376PortsViaNoobtocol((string)pluginConfig["serialPortNumber"]);
            cpu = context.Cpu;
            slots = context.SlotsSystem;
            context.Cpu.BeforeInstructionFetch += Cpu_BeforeInstructionFetch;
            ParseSymbols(@"C:\code\fun\RookieDrive\msx\.sym");
            addressesToLog = symbolsToLog.ToDictionary(s => symbolsByName[s], s => s);
            //cpu.BeforeInstructionExecution += Cpu_BeforeInstructionExecution;
        }

        private static readonly byte[] ldirOpcode = new byte[] {0xED, 0xB0};
        private void Cpu_BeforeInstructionExecution(object sender, BeforeInstructionExecutionEventArgs e)
        {
            if (indentation != "" && e.Opcode.SequenceEqual(ldirOpcode))
                Debug.WriteLine($"{indentation}LDIR from 0x{cpu.Registers.HL:X4} to 0x{cpu.Registers.DE:X4}, length {cpu.Registers.BC}");
        }

        private void ParseSymbols(string symbolsFilePath)
        {
            var lines = File.ReadAllLines(symbolsFilePath);
            var symbols = new Dictionary<string, ushort>();
            foreach (var line in lines)
            {
                var label = line.Split(':')[0];
                var valueString = line.Split(' ').Last().TrimEnd('h').Substring(4);
                var value = Convert.ToUInt16(valueString, 16);
                symbolsByName.Add(label, value);
            }
        }

        private void UdpateIndentation()
        {
            indentation = new string(' ', trackedCallsStack.Count);
        }

        private void Cpu_BeforeInstructionFetch(object sender, BeforeInstructionFetchEventArgs e)
        {
            var pc = cpu.Registers.PC;
            if (addressesToLog.ContainsKey(pc))
            {
                var symbol = addressesToLog[pc];
                Debug.WriteLine($"{indentation}--> {symbol}: HL=0x{cpu.Registers.HL:X4}, DE=0x{cpu.Registers.DE:X4}, BC={cpu.Registers.BC} (0x{cpu.Registers.BC:X4}), A={cpu.Registers.A}, Cy={cpu.Registers.CF}");
                var returnAddress = NumberUtils.CreateUshort(cpu.Memory[cpu.Registers.SP], cpu.Memory[cpu.Registers.SP + 1]);
                trackedCallsStack.Push(returnAddress);
                trackedCallsStackSymbols.Push(symbol);
                UdpateIndentation();
            }
            if (trackedCallsStack.Any() && trackedCallsStack.Peek() == pc)
            {
                trackedCallsStack.Pop();
                var symbol = trackedCallsStackSymbols.Pop();
                UdpateIndentation();
                Debug.WriteLine($"{indentation}<-- {symbol}: HL=0x{cpu.Registers.HL:X4}, DE=0x{cpu.Registers.DE:X4}, BC={cpu.Registers.BC} (0x{cpu.Registers.BC:X4}), A={cpu.Registers.A}, Cy={cpu.Registers.CF}");
            }
        }

        private void Cpu_MemoryAccess(object sender, MemoryAccessEventArgs e)
        {
            if(e.Address == 0x20)
            {
                if (e.EventType == MemoryAccessEventType.BeforePortRead)
                {
                    e.CancelMemoryAccess = true;
                    if(waitingMultiDataTransferLength)
                    {
                        waitingMultiDataTransferLength = false;
                        e.Value = chPorts.ReadData();
                        multiDataTransferRemaining = e.Value;
                        multiDataTransferPointer = 0;
                        if (e.Value > 0)
                            multiDataTransferBuffer = chPorts.ReadMultipleData(multiDataTransferRemaining);
                    }
                    else if (multiDataTransferRemaining > 0)
                    {
                        e.Value = multiDataTransferBuffer[multiDataTransferPointer];
                        multiDataTransferPointer++;
                        multiDataTransferRemaining--;
                    }
                    else
                    {
                        e.Value = chPorts.ReadData();
                    }
                }
                else if (e.EventType == MemoryAccessEventType.BeforePortWrite)
                {
                    e.CancelMemoryAccess = true;

                    if (waitingMultiDataTransferLength)
                    {
                        waitingMultiDataTransferLength = false;
                        multiDataTransferBuffer = new byte[e.Value];
                        multiDataTransferPointer = 0;
                        multiDataTransferRemaining = e.Value;
                        chPorts.WriteData(e.Value);
                    }
                    else if (multiDataTransferRemaining > 0)
                    {
                        multiDataTransferBuffer[multiDataTransferPointer] = e.Value;
                        multiDataTransferPointer++;
                        multiDataTransferRemaining--;
                        if(multiDataTransferRemaining == 0)
                            chPorts.WriteMultipleData(multiDataTransferBuffer);
                    }
                    else
                    {
                        chPorts.WriteData(e.Value);
                    }
                }
            }
            else if (e.Address == 0x21)
            {
                if (e.EventType == MemoryAccessEventType.BeforePortRead)
                {
                    e.CancelMemoryAccess = true;
                    e.Value = chPorts.ReadStatus();
                }
                else if (e.EventType == MemoryAccessEventType.BeforePortWrite)
                {
                    e.CancelMemoryAccess = true;
                    chPorts.WriteCommand(e.Value);

                    if (e.Value == CMD_RD_USB_DATA0 || e.Value == CMD_WR_HOST_DATA)
                        waitingMultiDataTransferLength = true;
                }
            }
            
        }
    }
}
