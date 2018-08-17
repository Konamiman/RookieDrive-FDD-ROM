namespace Konamiman.RookieDrive.Usb
{
    public class UsbStandardRequest
    {
        public static readonly byte GET_STATUS = 0;
        public static readonly byte CLEAR_FEATURE = 1;
        public static readonly byte SET_FEATURE = 3;
        public static readonly byte SET_ADDRESS = 5;
        public static readonly byte GET_DESCRIPTOR = 6;
        public static readonly byte SET_DESCRIPTOR = 7;
        public static readonly byte GET_CONFIGURATION = 8;
        public static readonly byte SET_CONFIGURATION = 9;
        public static readonly byte GET_INTERFACE = 10;
        public static readonly byte SET_INTERFACE = 11;
        public static readonly byte SYNCH_FRAME = 12;
    }
}
