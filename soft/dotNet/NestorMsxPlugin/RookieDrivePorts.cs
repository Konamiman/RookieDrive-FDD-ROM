using Konamiman.NestorMSX;
using Konamiman.RookieDrive.Usb;
using System.Collections.Generic;
using Konamiman.Z80dotNet;

namespace Konamiman.RookieDrive.NestorMsxPlugin
{
    [NestorMSXPlugin("RookieDrive ports")]
    public class RookieDrivePortsPlugin
    {
        private readonly ICH376Ports chPorts;

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
                    e.Value = chPorts.ReadData();
                }
                else if (e.EventType == MemoryAccessEventType.BeforePortWrite)
                {
                    e.CancelMemoryAccess = true;
                    chPorts.WriteData(e.Value);
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
                }
            }
        }
    }
}
