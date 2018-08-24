namespace Konamiman.RookieDrive.Usb
{
    public interface IUsbCbiTransport
    {
        UsbCbiCommandResult ExecuteCommand(byte[] command, byte[] dataBuffer, int dataIndex, int dataLength, UsbDataDirection dataDirection);
    }
}
