using System;

namespace Konamiman.RookieDrive.Usb
{
    public class UsbSetupPacket
    {
        public static UsbSetupPacket FromBytes(byte[] packetBytes)
        {
            if (packetBytes.Length != 8)
                throw new ArgumentException($"Length of {nameof(packetBytes)} must be 8");

            var p = new UsbSetupPacket
            {
                bmRequestType = packetBytes[0],
                bRequest = packetBytes[1],
                wValueL = packetBytes[2],
                wValueH = packetBytes[3],
                wIndexL = packetBytes[4],
                wIndexH = packetBytes[5],
                wLengthL = packetBytes[6],
                wLengthH = packetBytes[7]
            };

            return p;
        }

        public static UsbSetupPacket FromWords(short[] packetWords)
        {
            if (packetWords.Length != 4)
                throw new ArgumentException($"Length of {nameof(packetWords)} must be 4");

            var p = new UsbSetupPacket
            {
                bmRequestType = (byte)(packetWords[0] & 0x0F),
                bRequest = (byte)(packetWords[0] >> 8),
                wValue = packetWords[1],
                wIndex = packetWords[2],
                wLength = packetWords[3]
            };

            return p;
        }

        public UsbSetupPacket(byte bRequest, byte bmRequestType)
        {
            this.bmRequestType = bmRequestType;
            this.bRequest = bRequest;
        }

        private UsbSetupPacket()
        {
        }

        public byte[] ToByteArray()
        {
            return new byte[] { bmRequestType, bRequest, wValueL, wValueH, wIndexL, wIndexH, wLengthL, wLengthH };
        }

        public byte bmRequestType { get; set; }

        public byte bRequest { get; set; }

        public byte wValueL { get; set; }

        public byte wValueH { get; set; }

        public byte wIndexL { get; set; }

        public byte wIndexH { get; set; }

        public byte wLengthL { get; set; }

        public byte wLengthH { get; set; }

        public short wValue
        {
            get
            {
                return ShortFromBytes(wValueL, wValueH);
            }

            set
            {
                wValueL = Low(value);
                wValueH = High(value);
            }
        }

        public short wIndex
        {
            get
            {
                return ShortFromBytes(wIndexL, wIndexH);
            }

            set
            {
                wIndexL = Low(value);
                wIndexH = High(value);
            }
        }

        public short wLength
        {
            get
            {
                return ShortFromBytes(wLengthL, wLengthH);
            }

            set
            {
                wLengthL = Low(value);
                wLengthH = High(value);
            }
        }

        public UsbDataDirection DataDirection => (UsbDataDirection)(bmRequestType & 0x80);

        private short ShortFromBytes(byte low, byte high) => (short)(low | (high << 8));

        private byte Low(short value) => (byte)(value & 0xFF);

        private byte High(short value) => (byte)(value >> 8);
    }
}
