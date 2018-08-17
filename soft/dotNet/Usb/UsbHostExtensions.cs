using System.Linq;

namespace Konamiman.RookieDrive.Usb
{
    public static class UsbHostExtensions
    {
        public static byte[] ExecuteControlInTransfer(this IUsbHost usbHost, UsbSetupPacket setupPacket, int deviceAddress, int endpointNumber = 0)
        {
            var dataBuffer = new byte[setupPacket.wLength];
            var result = usbHost.ExecuteControlTransfer(setupPacket, dataBuffer, 0, deviceAddress, endpointNumber);
            if (result.IsError)
                throw new UsbTransferException(result.TransactionResult);

            return dataBuffer.Take(result.TransferredDataCount).ToArray();
        }
    }
}
