namespace Konamiman.RookieDrive.Usb
{
    public interface ICH376Ports
    {
        void WriteCommand(byte command);

        bool IntIsActive { get; }

        void WriteData(byte data);

        byte ReadData();
    }
}
