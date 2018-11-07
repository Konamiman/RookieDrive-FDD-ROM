using System;

namespace Konamiman.RookieDrive.Usb
{
    public class UsbTransferException : Exception
    {
        UsbPacketResult Result { get; }

        public UsbTransferException(string message, UsbPacketResult result) : base(message)
        {
            this.Result = result;
        }

        public UsbTransferException(UsbPacketResult result) : this($"USB transfer exception: {result}", result)
        {
        }
    }
}
