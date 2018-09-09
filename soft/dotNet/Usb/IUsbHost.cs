namespace Konamiman.RookieDrive.Usb
{
    public interface IUsbHost
    {
        void Reset();

        bool UpdateDeviceConnectionStatus();

        byte[] ConnectedDeviceAddresses { get; }

        IUsbHostHardware HostHardware { get; }

        UsbConnectedDevice GetConnectedDeviceInfo(byte deviceAddress);

        UsbTransferResult ExecuteControlTransfer(UsbSetupPacket setupPacket, byte[] dataBuffer, int dataBufferIndex, int deviceAddress, int endpointNumber = 0);

        UsbTransferResult ExecuteDataInTransfer(byte[] dataBuffer, int dataBufferIndex, int dataLength, int deviceAddress, int endpointNumber);

        UsbTransferResult ExecuteDataOutTransfer(byte[] dataBuffer, int dataBufferIndex, int dataLength, int deviceAddress, int endpointNumber);
    }
}
