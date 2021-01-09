namespace Konamiman.RookieDrive.Usb
{
    public enum UsbPacketResult
    {
        Ok,
        Nak = 1,
        Stall = 2,
        Timeout = 3,
        DataError = 4,
        OtherError = 5,
        NoDeviceConnected = 6,
        NotImplemented = 7,
        USB_INT_SUCCESS = 0x14,
        USB_INT_CONNECT = 0x15,
        USB_INT_DISCONNECT = 0x16,
        USB_INT_BUF_OVER = 0x17,
        USB_INT_USB_READY = 0x18,
        USB_INT_DISK_READ = 0x1D,
        USB_INT_DISK_WRITE = 0x1E,
        USB_INT_DISK_ERR = 0x1F,
        ERR_OPEN_DIR = 0x41,
        ERR_MISS_FILE = 0x42,
        ERR_FOUND_NAME = 0x43,
        ERR_DISK_DISCON = 0x82,
        ERR_LARGE_SECTOR = 0x84,
        ERR_TYPE_ERROR = 0x92,
        ERR_BPB_ERROR = 0xA1,
        ERR_DISK_FULL = 0xB1,
        ERR_FDT_OVER = 0xB2,
        ERR_FILE_CLOSE = 0xB4
    }
}
