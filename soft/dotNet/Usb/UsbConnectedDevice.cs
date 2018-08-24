using System.Collections.Generic;
using System.Linq;

namespace Konamiman.RookieDrive.Usb
{
    public class UsbConnectedDevice
    {
        public UsbConnectedDevice(byte endpointZeroMaxPacketSize, byte @class, byte subclass, byte protocol, int vendorId, int productId, byte manufacturerStringIndex, byte productStringIndex, UsbInterface[] interfacesForCurrentConfiguration)
        {
            this.EndpointZeroMaxPacketSize = endpointZeroMaxPacketSize;
            this.Class = @class;
            this.Subclass = subclass;
            this.Protocol = protocol;
            this.VendorId = vendorId;
            this.ProductId = productId;
            this.ManufacturerStringIndex = manufacturerStringIndex;
            this.ProductStringIndex = productStringIndex;
            this.InterfacesForCurrentConfiguration = interfacesForCurrentConfiguration;

            this.EndpointsByNumber = interfacesForCurrentConfiguration
                .SelectMany(i => i.Endpoints)
                .ToDictionary(e => e.Number);
        }

        public byte EndpointZeroMaxPacketSize { get; }

        public byte Class { get; }

        public byte Subclass { get; }

        public byte Protocol { get; }

        public int VendorId { get; }

        public int ProductId { get; }

        public byte ManufacturerStringIndex { get; }

        public byte ProductStringIndex { get; }

        public UsbInterface[] InterfacesForCurrentConfiguration { get; }

        internal Dictionary<byte, UsbEndpoint> EndpointsByNumber { get; }
    }
}
