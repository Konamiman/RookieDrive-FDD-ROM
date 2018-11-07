using System.Diagnostics;

namespace Konamiman.RookieDrive.Usb
{
    public static class UsbCbiTransportExtensions
    {
        private static readonly byte[] requestSenseCommand = new byte[] { 3, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0 };
        private static readonly byte[] requestSenseBuffer = new byte[1];

        public static UsbCbiCommandResult ExecuteCommandWithRetry(this IUsbCbiTransport cbi, byte[] command, byte[] dataBuffer, int dataIndex, int dataLength, UsbDataDirection dataDirection, bool retryOnMediaChanged = true)
        {
            return ExecuteCommandWithRetry(cbi, command, dataBuffer, dataIndex, dataLength, dataDirection, out bool dummyMediaChanged, retryOnMediaChanged);
        }

        public static UsbCbiCommandResult ExecuteCommandWithRetry(this IUsbCbiTransport cbi, byte[] command, byte[] dataBuffer, int dataIndex, int dataLength, UsbDataDirection dataDirection, out bool mediaChanged, bool retryOnMediaChanged = true)
        {
            UsbCbiCommandResult result;
            mediaChanged = false;

            while(true)
            {
                result = cbi.ExecuteCommand(command, dataBuffer, dataIndex, dataLength, dataDirection);
                if (!result.IsError || result.SenseData == null)
                    return result;

                if (result.SenseData == null)
                    Debug.WriteLine("!!! No sense data on int endpoint!");
                else
                    Debug.WriteLine($"!!! ASC: {result.SenseData[0]:X2}h, ASCQ: {result.SenseData[1]:X2}h");

                cbi.ExecuteCommand(requestSenseCommand, requestSenseBuffer, 0, 1, UsbDataDirection.IN);

                var asc = result.SenseData[0];
                var ascq = result.SenseData[1];

                //4,1 = LOGICAL DRIVE NOT READY - BECOMING READY
                //4,FF = LOGICAL DRIVE NOT READY - DEVICE IS BUSY
                //28 = NOT READY TO READY TRANSITION - MEDIA CHANGED
                //28..2F = UNIT ATTENTION
                if ((asc < 0x28 || asc > 0x2F) && !(asc == 4 && (ascq == 1 || ascq == 0xFF)))
                    return result;

                if (asc == 0x28)
                {
                    mediaChanged = true;
                    if (!retryOnMediaChanged)
                        return result;
                }
            }
        }
    }
}
