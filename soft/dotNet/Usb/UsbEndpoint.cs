namespace Konamiman.RookieDrive.Usb
{
    public class UsbEndpoint
    {
        public UsbEndpoint(byte number, UsbEndpointType type, int maxPacketSize)
        {
            this.Number = number;
            this.Type = type;
            this.MaxPacketSize = maxPacketSize;
            this.DataDirection = (UsbDataDirection)(number & 0x80);
        }

        public UsbDataDirection DataDirection { get; }

        public UsbEndpointType Type { get; }

        public byte Number { get; }

        public int MaxPacketSize { get; }

        internal int ToggleBit { get; private set; }

        internal void FlipToggleBit()
        {
            ToggleBit ^= 1;
        }

        internal void ResetToggleBit() => ToggleBit = 0;
    }
}
