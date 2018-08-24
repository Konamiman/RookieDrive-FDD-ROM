using System;
using System.Linq;

namespace Konamiman.RookieDrive.Usb
{
    public class UsbHost : IUsbHost
    {
        const byte UsbDeviceAddress = 1;
        private static readonly byte[] UsbDeviceAddressArray = new byte[] { UsbDeviceAddress };
        private static readonly byte[] NoDevices = new byte[0];

        private readonly IUsbHostHardware hw;

        private UsbConnectedDevice connectedDevice = null;

        public UsbHost(IUsbHostHardware hostHardware)
        {
            this.hw = hostHardware;
            Reset();
        }

        public byte[] ConnectedDeviceAddresses => connectedDevice == null ? NoDevices : UsbDeviceAddressArray;

        public UsbConnectedDevice GetConnectedDeviceInfo(byte deviceAddress)
        {
            if (deviceAddress != UsbDeviceAddress)
                return null;

            return connectedDevice;
        }

        public UsbTransferResult ExecuteControlTransfer(UsbSetupPacket setupPacket, byte[] dataBuffer, int dataBufferIndex, int deviceAddress, int endpointNumber = 0)
        {
            //TODO: Some requests need special handling:
            //- SET_ADDRESS: Disallow it (we manage device addresses ourselves)
            //- SET_CONFIGURATION: Execute and refresh the connected device info with the new set of interfaces + endpoints
            //- SET_INTERFACE: Disallow it (until we support alternate settings at least)
            //- CLEAR_FEATURE(ENDPOINT_HALT): Execute and reset the toggle bit for the endpoint in the device info

            if (connectedDevice == null)
                return new UsbTransferResult(UsbPacketResult.NoDeviceConnected);

            if(setupPacket.bRequest == UsbStandardRequest.GET_DESCRIPTOR)
            {
                var result = GetDescriptor(deviceAddress, setupPacket.wValueH, setupPacket.wValueL, setupPacket.wIndex, connectedDevice.EndpointZeroMaxPacketSize, out byte[] buffer);
                if (!result.IsError)
                    Array.Copy(buffer, 0, dataBuffer, dataBufferIndex, result.TransferredDataCount);

                return result;
            }

            return hw.ExecuteControlTransfer(setupPacket, dataBuffer, dataBufferIndex, deviceAddress, connectedDevice.EndpointZeroMaxPacketSize, endpointNumber);
        }

        public void Reset()
        {
            hw.HardwareReset();
            UpdateDeviceConnectionStatus();
        }

        public void UpdateDeviceConnectionStatus()
        {
            var hwDeviceStatus = hw.CheckConnectionStatus();
            if (hwDeviceStatus == UsbDeviceConnectionStatus.NotConnected)
                connectedDevice = null;
            else if (hwDeviceStatus == UsbDeviceConnectionStatus.Changed)
                InitializeDevice();
            else if (hwDeviceStatus == UsbDeviceConnectionStatus.Error)
                throw new UsbTransferException("Error on USB bus reset", UsbPacketResult.OtherError);
        }

        private UsbTransferResult GetDescriptor(int deviceAddress, byte descriptorType, byte descriptorIndex, int languageId, byte endpointZeroMaxPacketSize, out byte[] descriptorBytes)
        {
            UsbTransferResult result;
            if(hw is IUsbHardwareShortcuts)
            {
                result = ((IUsbHardwareShortcuts)hw).GetDescriptor(deviceAddress, descriptorType, descriptorIndex, languageId, out descriptorBytes);
                if (!result.IsError || result.TransactionResult != UsbPacketResult.NotImplemented)
                    return result;
            }

            descriptorBytes = new byte[255];
            UsbSetupPacket getDescriptorSetupPacket = new UsbSetupPacket(UsbStandardRequest.GET_DESCRIPTOR, 0x80);
            getDescriptorSetupPacket.wValueH = descriptorType;
            getDescriptorSetupPacket.wValueL = descriptorIndex;
            getDescriptorSetupPacket.wLength = (short)descriptorBytes.Length;
            getDescriptorSetupPacket.wIndex = (short)languageId;
            result = hw.ExecuteControlTransfer(getDescriptorSetupPacket, descriptorBytes, 0, deviceAddress, endpointZeroMaxPacketSize, 0);
            if(result.IsError)
            {
                descriptorBytes = null;
                return result;
            }

            descriptorBytes = descriptorBytes.Take(result.TransferredDataCount).ToArray();
            return result;
        }

        private UsbPacketResult InitializeDevice()
        {
            byte[] data = new byte[255];
            UsbTransferResult result;
            UsbSetupPacket getDescriptorSetupPacket = new UsbSetupPacket(UsbStandardRequest.GET_DESCRIPTOR, 0x80);
            byte endpointZeroMaxPacketSize = 8;

            //Here device is in DEFAULT state (hw did bus reset already):

            result = GetDescriptor(0, UsbDescriptorType.DEVICE, 0, 0, endpointZeroMaxPacketSize, out data);
            if (result.IsError)
                throw new UsbTransferException($"When getting device descriptor: {result.TransactionResult}", result.TransactionResult);

            endpointZeroMaxPacketSize = data[7];

            var deviceDescriptorBytes = data.Take(result.TransferredDataCount).ToArray();

            var setAddressSetupPacket = new UsbSetupPacket(UsbStandardRequest.SET_ADDRESS, 0);
            setAddressSetupPacket.wValue = UsbDeviceAddress;
            result = hw.ExecuteControlTransfer(setAddressSetupPacket, null, 0, 0, endpointZeroMaxPacketSize);
            if (result.IsError)
                throw new UsbTransferException($"When setting device address: {result.TransactionResult}", result.TransactionResult);

            //Here device is in ADDRESS state

            getDescriptorSetupPacket.wValueH = UsbDescriptorType.CONFIGURATION;
            getDescriptorSetupPacket.wValueL = 0; //We're interested in the first pconfiguration available
            getDescriptorSetupPacket.wLength = (short)data.Length;

            result = GetDescriptor(UsbDeviceAddress, UsbDescriptorType.CONFIGURATION, 0, 0, endpointZeroMaxPacketSize, out data);
            if (result.IsError)
                throw new UsbTransferException($"When getting configuration descriptor: {result.TransactionResult}", result.TransactionResult);

            var bConfigurationValue = data[5];
            var configurationDescriptorLength = result.TransferredDataCount;

            var setConfigSetupPacket = new UsbSetupPacket(UsbStandardRequest.SET_CONFIGURATION, 0);
            setConfigSetupPacket.wValueL = bConfigurationValue;
            result = hw.ExecuteControlTransfer(setConfigSetupPacket, null, 0, UsbDeviceAddress, endpointZeroMaxPacketSize);
            if (result.IsError)
                throw new UsbTransferException($"When setting device configuration: {result.TransactionResult}", result.TransactionResult);

            //Here device is in CONFIGURED state

            var interfacesInfo = GetInterfacesInfo(data.Take(configurationDescriptorLength).ToArray());
            connectedDevice = new UsbConnectedDevice(
                endpointZeroMaxPacketSize,
                deviceDescriptorBytes[4],
                deviceDescriptorBytes[5],
                deviceDescriptorBytes[6],
                (int)(deviceDescriptorBytes[8] | (deviceDescriptorBytes[9] << 8)),
                (int)(deviceDescriptorBytes[10] | (deviceDescriptorBytes[11] << 8)),
                deviceDescriptorBytes[14],
                deviceDescriptorBytes[15],
                interfacesInfo);

            return UsbPacketResult.Ok;
        }

        //Descriptors appear concatenated as follows:
        //  configuration descriptor
        //    interface 0, alt setting 0 descriptor
        //      endpoint 0 for interface 0 alt setting 0 descriptor
        //      endpoint 1 for interface 0 alt setting 0 descriptor
        //    interface 0, alt setting 1 descriptor
        //      endpoint 0 for interface 0 alt setting 1 descriptor
        //      endpoint 1 for interface 0 alt setting 1 descriptor
        //    interface 1, alt setting 0 descriptor
        //      endpoint 0 for interface 1 alt setting 0 descriptor
        //      endpoint 1 for interface 1 alt setting 0 descriptor
        //    interface 2, alt setting 0 descriptor
        //      endpoint 0 for interface 2 alt setting 0 descriptor
        //      endpoint 1 for interface 2 alt setting 0 descriptor
        private UsbInterface[] GetInterfacesInfo(byte[] configurationDescriptor)
        {
            var remainingDescriptorBytes = configurationDescriptor;

            void GoToNextDescriptor()
            {
                if (remainingDescriptorBytes.Length > 0)
                    remainingDescriptorBytes = remainingDescriptorBytes.Skip(remainingDescriptorBytes[0]).ToArray();
            }

            byte DescriptorByteAt(int index) => remainingDescriptorBytes[index];

            var interfacesCount = DescriptorByteAt(4);
            var interfaces = new UsbInterface[interfacesCount];

            GoToNextDescriptor();   //1st interface descriptor

            for(var interfaceIndex = 0; interfaceIndex < interfacesCount; interfaceIndex++)
            {
                var endpointsCount = DescriptorByteAt(4);
                var alternateSettingIndex = DescriptorByteAt(3);

                //TODO: Add support for alternate settings
                if (alternateSettingIndex != 0)
                {
                    GoToNextDescriptor();   //1st endpoint descriptor
                    for(int i = 0; i < endpointsCount; i++)
                        GoToNextDescriptor();   //Next endpoint descriptor

                    continue;
                }

                var interfaceNumber = DescriptorByteAt(2);
                var @class = DescriptorByteAt(5);
                var subclass = DescriptorByteAt(6);
                var protocol = DescriptorByteAt(7);

                var endpoints = new UsbEndpoint[endpointsCount];

                GoToNextDescriptor();   //1st endpoint descriptor

                for (var endpointIndex = 0; endpointIndex < endpointsCount; endpointIndex++)
                {
                    endpoints[endpointIndex] = new UsbEndpoint(
                        number: DescriptorByteAt(2),
                        type: (UsbEndpointType)DescriptorByteAt(3),
                        maxPacketSize: DescriptorByteAt(4) | DescriptorByteAt(5));

                    GoToNextDescriptor();   //Next endpoint descriptor
                }

                interfaces[interfaceIndex] = new UsbInterface(interfaceNumber, @class, subclass, protocol, endpoints);

                GoToNextDescriptor();   //Next interface descriptor
            }

            return interfaces.Where(i => i != null).ToArray();
        }

        public UsbTransferResult ExecuteDataInTransfer(byte[] dataBuffer, int dataBufferIndex, int dataLength, int deviceAddress, int endpointNumber)
        {
            return ExecuteDataTransfer(dataBuffer, dataBufferIndex, dataLength, deviceAddress, endpointNumber, UsbDataDirection.IN);
        }

        public UsbTransferResult ExecuteDataOutTransfer(byte[] dataBuffer, int dataBufferIndex, int dataLength, int deviceAddress, int endpointNumber)
        {
            return ExecuteDataTransfer(dataBuffer, dataBufferIndex, dataLength, deviceAddress, endpointNumber, UsbDataDirection.OUT);
        }

        private UsbTransferResult ExecuteDataTransfer(byte[] dataBuffer, int dataBufferIndex, int dataLength, int deviceAddress, int endpointNumber, UsbDataDirection dataDirection)
        {
            if (deviceAddress != UsbDeviceAddress)
                throw new InvalidOperationException($"There's no device connected with address {deviceAddress}");

            if (!connectedDevice.EndpointsByNumber.ContainsKey((byte)endpointNumber))
                throw new InvalidOperationException($"The device with address {deviceAddress} doesn't have an endpoint with number 0x{endpointNumber:X} in any of the interfaces of the current configuration");

            if ((UsbDataDirection)(endpointNumber & 0x80) != dataDirection)
                throw new InvalidOperationException($"Can't perform {dataDirection} transfers on endpoint 0x{endpointNumber:X}, it's not an {dataDirection} endpoint");

            var endpointType = connectedDevice.EndpointsByNumber[(byte)endpointNumber].Type;

            if(endpointType != UsbEndpointType.Bulk && endpointType != UsbEndpointType.Interrupt)
                throw new InvalidOperationException($"Can't perform data transfers on endpoint 0x{endpointNumber:X}, it's a {endpointType} endpoint");

            if(dataDirection == UsbDataDirection.OUT && endpointType == UsbEndpointType.Interrupt)
                throw new InvalidOperationException($"Can't perform OUT data transfers on endpoint 0x{endpointNumber:X}, it's an Interrupt endpoint");

            var endpoint = connectedDevice.EndpointsByNumber[(byte)endpointNumber];

            var result = dataDirection == UsbDataDirection.IN ?
                hw.ExecuteDataInTransfer(dataBuffer, dataBufferIndex, dataLength, deviceAddress, endpointNumber, endpoint.MaxPacketSize, endpoint.ToggleBit) :
                hw.ExecuteDataOutTransfer(dataBuffer, dataBufferIndex, dataLength, deviceAddress, endpointNumber, endpoint.MaxPacketSize, endpoint.ToggleBit);

            endpoint.ToggleBit = result.NextTogleBit;

            return result;
        }
    }
}
