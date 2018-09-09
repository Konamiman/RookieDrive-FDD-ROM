namespace Konamiman.RookieDrive.Usb
{
    public interface IUsbHardwareShortcuts
    {
        UsbTransferResult GetDescriptor(int deviceAddress, byte descriptorType, byte descriptorIndex, int languageId, out byte[] descriptorBytes);

        UsbTransferResult ClearEndpointHalt(int deviceAddress, byte endpointNumber);
    }
}
