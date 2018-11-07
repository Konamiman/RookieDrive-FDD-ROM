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
            if (device.VendorId == 0x0644 && device.ProductId == 1)
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

        private readonly byte[] requestSenseCommand = new byte[] { 3, 0, 0, 0, 14, 0, 0, 0, 0, 0, 0, 0 };

        public UsbCbiCommandResult ExecuteCommand(byte[] command, byte[] dataBuffer, int dataIndex, int dataLength, UsbDataDirection dataDirection)
        {
            adsc.wLength = (short)command.Length;
            var commandTransferResult = host.ExecuteControlTransfer(adsc, command, 0, deviceAddress);
            if (commandTransferResult.IsErrorButNotStall)
                return new UsbCbiCommandResult(commandTransferResult.TransactionResult, 0, null);

            UsbCbiCommandResult ResultOnError(int transferredLength)
            {
                if (command[0] == requestSenseCommand[0])
                    return new UsbCbiCommandResult(commandTransferResult.TransactionResult, transferredLength, null);

                var requestSenseResult = ExecuteRequestSense();
                if (requestSenseResult.IsErrorResult)
                    return new UsbCbiCommandResult(commandTransferResult.TransactionResult, transferredLength, null);
                else
                    return new UsbCbiCommandResult(UsbPacketResult.Ok, transferredLength, requestSenseResult.ToByteArray());
            }

            if (commandTransferResult.IsError)
            {
                return ResultOnError(0);
            }

            var transferredDataCount = 0;
            if (dataLength != 0)
            {
                var dataTransferResult = dataDirection == UsbDataDirection.IN ?
                    host.ExecuteDataInTransfer(dataBuffer, dataIndex, dataLength, deviceAddress, bulkInEndpoint.Number) :
                    host.ExecuteDataOutTransfer(dataBuffer, dataIndex, dataLength, deviceAddress, bulkOutEndpoint.Number);

                transferredDataCount = dataTransferResult.TransferredDataCount;

                if (dataTransferResult.IsErrorButNotStall)
                    return new UsbCbiCommandResult(dataTransferResult.TransactionResult, transferredDataCount, null);
                else if (dataTransferResult.IsError)
                {
                    ClearEndpointHalt(dataDirection == UsbDataDirection.IN ? bulkInEndpoint.Number : bulkOutEndpoint.Number);
                    return ResultOnError(transferredDataCount);
                }
            }

            var intTransferResult = host.ExecuteDataInTransfer(senseCodeBuffer, 0, 2, deviceAddress, interruptEndpoint.Number);
            if (intTransferResult.IsErrorButNotStall)
                return new UsbCbiCommandResult(intTransferResult.TransactionResult, transferredDataCount, null);
            else if (intTransferResult.IsError)
            {
                ClearEndpointHalt(interruptEndpoint.Number);
                return ResultOnError(transferredDataCount);
            }
            else if(senseCodeBuffer[0] != 0)
                return ResultOnError(transferredDataCount); //Request Sense needed to clear the error condition

            return new UsbCbiCommandResult(commandTransferResult.TransactionResult, transferredDataCount, senseCodeBuffer.ToArray());
        }

        private RequestSenseResult ExecuteRequestSense()
        {
            var requestSenseResponseBuffer = new byte[18];
            var requestSenseExecutionResult = ExecuteCommand(requestSenseCommand, requestSenseResponseBuffer, 0, 14, UsbDataDirection.IN);
            if (requestSenseExecutionResult.IsError)
                return new RequestSenseResult(requestSenseExecutionResult.TransactionResult, 0, 0);
            else
                return new RequestSenseResult(UsbPacketResult.Ok, requestSenseResponseBuffer[12], requestSenseResponseBuffer[13]);
        }

        private class RequestSenseResult
        {
            public RequestSenseResult(UsbPacketResult result, byte asc, byte ascq)
            {
                this.Result = result;
                this.Asc = asc;
                this.Ascq = ascq;
            }

            public UsbPacketResult Result { get; }
            public byte Asc { get; }
            public byte Ascq { get; }

            public bool IsErrorResult => Result != UsbPacketResult.Ok;

            public byte[] ToByteArray() => new[] { Asc, Ascq };
        }

        public void ClearEndpointHalt(byte endpointNumber)
        {
            UsbTransferResult result;

            if(host.HostHardware is IUsbHardwareShortcuts)
            {
                result = ((IUsbHardwareShortcuts)host.HostHardware).ClearEndpointHalt(deviceAddress, endpointNumber);
                if (result.TransactionResult != UsbPacketResult.NotImplemented)
                    return;
            }

            var setupPacket = new UsbSetupPacket(UsbStandardRequest.SET_FEATURE, 2);
            setupPacket.wIndexL = endpointNumber;
            result = host.ExecuteControlTransfer(setupPacket, null, 0, deviceAddress);

            setupPacket = new UsbSetupPacket(UsbStandardRequest.CLEAR_FEATURE, 2);
            setupPacket.wIndexL = endpointNumber;
            result = host.ExecuteControlTransfer(setupPacket, null, 0, deviceAddress);
        }
    }
}
