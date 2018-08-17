namespace Konamiman.RookieDrive.Usb
{
    public class UsbConnectedDevice
    {
        public UsbConnectedDevice(byte endpointZeroMaxPacketSize, byte @class, byte subclass, byte protocol, UsbInterface[] interfacesForCurrentConfiguration)
        {
            this.EndpointZeroMaxPacketSize = endpointZeroMaxPacketSize;
            this.Class = @class;
            this.Subclass = subclass;
            this.Protocol = protocol;
            this.InterfacesForCurrentConfiguration = interfacesForCurrentConfiguration;
        }

        public byte EndpointZeroMaxPacketSize { get; }

        public byte Class { get; }

        public byte Subclass { get; }

        public byte Protocol { get; }

        public UsbInterface[] InterfacesForCurrentConfiguration { get; }
    }
}
