using System;
using System.Linq;

namespace Konamiman.RookieDrive.Usb
{
    public class UsbCbiTransport : IUsbCbiTransport
    {
        IUsbHost host;
        UsbEndpoint bulkInEndpoint;
        UsbEndpoint bulkOutEndpoint;
        UsbEndpoint interruptEndpoint;
        UsbSetupPacket adsc;
        readonly int deviceAddress;
        byte[] senseCodeBuffer = new byte[2];

        public UsbCbiTransport(IUsbHost host, int deviceAddress)
        {
            var device = host.GetConnectedDeviceInfo((byte)deviceAddress);
            if (device == null)
                throw new InvalidOperationException($"There's no device connected with address {deviceAddress}");

            //HACK: Detect Konamiman's Traxdata FDD by VID+PID,
            //since it's a fully compliant CBI+UFI FDD but it identifies itself with class = FFh
            UsbInterface iface;
            if (device.VendorId == 0x4408 && device.ProductId == 0x0601)
                iface = device.InterfacesForCurrentConfiguration.First();
            else
                iface = device.InterfacesForCurrentConfiguration.Where(i =>
                        i.Class == 8 &&
                        i.Subclass == 4 &&
                        i.Protocol == 0)
                    .SingleOrDefault();

            if (iface == null)
                throw new InvalidOperationException("The device does not implement mass storage with the CBI transport on any of the interfaces for the current configuration");

            this.deviceAddress = deviceAddress;
            this.host = host;
            bulkInEndpoint = iface.Endpoints.Where(e => e.Type == UsbEndpointType.Bulk && e.DataDirection == UsbDataDirection.IN).First();
            bulkOutEndpoint = iface.Endpoints.Where(e => e.Type == UsbEndpointType.Bulk && e.DataDirection == UsbDataDirection.OUT).First();
            interruptEndpoint = iface.Endpoints.Where(e => e.Type == UsbEndpointType.Interrupt).First();
            adsc = new UsbSetupPacket(0, 0x21);
            adsc.wIndexL = iface.InterfaceNumber;
        }

        public UsbCbiCommandResult ExecuteCommand(byte[] command, byte[] dataBuffer, int dataIndex, int dataLength, UsbDataDirection dataDirection)
        {
            adsc.wLength = (short)command.Length;
            var commandTransferResult = host.ExecuteControlTransfer(adsc, command, 0, deviceAddress);
            if (commandTransferResult.IsError && commandTransferResult.TransactionResult != UsbPacketResult.Stall)
                return new UsbCbiCommandResult(commandTransferResult.TransactionResult, 0, null);

            var transferredDataCount = 0;
            if (dataLength != 0 && commandTransferResult.TransactionResult != UsbPacketResult.Stall)
            {
                var dataTransferResult = dataDirection == UsbDataDirection.IN ?
                    host.ExecuteDataInTransfer(dataBuffer, dataIndex, dataLength, deviceAddress, bulkInEndpoint.Number) :
                    host.ExecuteDataOutTransfer(dataBuffer, dataIndex, dataLength, deviceAddress, bulkOutEndpoint.Number);

                transferredDataCount = dataTransferResult.TransferredDataCount;
                if (dataTransferResult.IsError)
                    return new UsbCbiCommandResult(dataTransferResult.TransactionResult, transferredDataCount, null);
            }

            var intTransferResult = host.ExecuteDataInTransfer(senseCodeBuffer, 0, 2, deviceAddress, interruptEndpoint.Number);
            if (intTransferResult.IsError)
                return new UsbCbiCommandResult(intTransferResult.TransactionResult, transferredDataCount, null);

            return new UsbCbiCommandResult(commandTransferResult.TransactionResult, transferredDataCount, senseCodeBuffer.ToArray());
        }
    }
}
