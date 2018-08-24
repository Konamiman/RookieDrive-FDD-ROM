namespace Konamiman.RookieDrive.Usb
{
    public enum UsbPacketResult
    {
        Ok,
        Nak,
        Stall,
        Timeout,
        DataError,
        OtherError,
        NoDeviceConnected,
        NotImplemented
    }
}
