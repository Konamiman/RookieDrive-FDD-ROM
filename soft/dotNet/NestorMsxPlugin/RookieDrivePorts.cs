using Konamiman.NestorMSX;
using Konamiman.RookieDrive.Usb;
using System.Collections.Generic;
using Konamiman.Z80dotNet;

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

        public RookieDrivePortsPlugin(PluginContext context, IDictionary<string, object> pluginConfig)
        {
            context.Cpu.MemoryAccess += Cpu_MemoryAccess;
            chPorts = UsbServiceProvider.GetCH376Ports();
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
                    chPorts.WriteData(e.Value);
#if false
                    if (waitingMultiDataTransferLength)
                    {
                        waitingMultiDataTransferLength = false;
                        multiDataTransferPointer = 0;
                        multiDataTransferRemaining = e.Value;
                    }
                    else if (multiDataTransferRemaining > 0)
                    {
                        multiDataTransferBuffer[multiDataTransferPointer] = e.Value;
                        multiDataTransferPointer++;
                        multiDataTransferRemaining--;
                        if(multiDataTransferRemaining == 0)
                        {
                            //...
                        }
                    }
                    else
                    {
                        chPorts.WriteData(e.Value);
                    }
#endif
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

                    if (e.Value == CMD_RD_USB_DATA0)
                        waitingMultiDataTransferLength = true;
                }
            }
        }
    }
}
