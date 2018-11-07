namespace Konamiman.RookieDrive.Usb
{
    public class UsbInterface
    {
        public UsbInterface(byte interfaceNumber, byte @class, byte subclass, byte protocol, UsbEndpoint[] endpoints)
        {
            this.InterfaceNumber = interfaceNumber;
            this.Class = @class;
            this.Subclass = subclass;
            this.Protocol = protocol;
            this.Endpoints = endpoints;
        }

        public byte InterfaceNumber { get; }

        public byte Class { get; }

        public byte Subclass { get; }

        public byte Protocol { get; }

        public UsbEndpoint[] Endpoints { get; }
    }
}
