namespace Konamiman.RookieDrive.Usb
{
    public interface ICH376Ports
    {
        void WriteCommand(byte command);

        bool IntIsActive { get; }

        bool DeviceIsBusy { get; }

        void WriteData(byte data);

        byte ReadData();

        byte ReadStatus();

        byte[] ReadMultipleData(int length);

        void WriteMultipleData(byte[] data);
    }
}
