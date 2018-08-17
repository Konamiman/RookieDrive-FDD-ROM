using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Konamiman.RookieDrive.Usb
{
    public class UsbInterface
    {
        public UsbInterface(byte @class, byte subclass, byte protocol, UsbEndpoint[] endpoints)
        {
            this.Class = @class;
            this.Subclass = subclass;
            this.Protocol = protocol;
            this.Endpoints = endpoints;
        }

        public byte Class { get; }

        public byte Subclass { get; }

        public byte Protocol { get; }

        public UsbEndpoint[] Endpoints { get; }
    }
}
