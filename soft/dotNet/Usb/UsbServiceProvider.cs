namespace Konamiman.RookieDrive.Usb
{
    public static class UsbServiceProvider
    {
        public static ICH376Ports GetCH376Ports(string serverIp = "localhost", int serverPort = 3434)
        {
            //return new CH376PortsViaOpc(serverIp, serverPort);
            return new CH376PortsViaNoobtocol("COM4");
        }
    }
}
