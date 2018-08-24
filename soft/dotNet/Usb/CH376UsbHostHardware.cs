using System;
using System.Threading;
using System.Linq;

namespace Konamiman.RookieDrive.Usb
{
    public class CH376UsbHostHardware : IUsbHostHardware, IUsbHardwareShortcuts
    {
        const byte RESET_ALL = 0x05;
        const byte WR_HOST_DATA = 0x2C;
        const byte RD_USB_DATA0 = 0x27;
        const byte ISSUE_TKN_X = 0x4E;
        const byte GET_STATUS = 0x22;
        const byte SET_USB_ADDR = 0x13;
        const byte SET_USB_MODE = 0x15;
        const byte GET_DESCR = 0x46;

        const byte PID_SETUP = 0x0D;
        const byte PID_IN = 0x09;
        const byte PID_OUT = 0x01;

        const byte INT_SUCCESS = 0x14;
        const byte INT_CONNECT = 0x15;
        const byte INT_DISCONNECT = 0x16;
        const byte USB_INT_BUF_OVER = 0x17;
        const byte CMD_RET_SUCCESS = 0x51;
        const byte CMD_RET_ABORT = 0x5F;

        private readonly ICH376Ports ch;
        private static readonly byte[] noData = new byte[0];

        public CH376UsbHostHardware(ICH376Ports ch376Ports)
        {
            this.ch = ch376Ports;

            HardwareReset();
            deviceIsConnected = false;
            SetHostWithoutSofMode();
        }

        bool deviceIsConnected = false;

        public void HardwareReset()
        {
            ch.WriteCommand(RESET_ALL);
            Thread.Sleep(50);
            SetHostWithoutSofMode();
        }

        private UsbPacketResult BusResetAndSetHostWithSofMode()
        {
            var result = SetUsbMode(7);
            if (result != UsbPacketResult.Ok)
                return result;

            Thread.Sleep(35);

            return SetUsbMode(6);
        }

        private UsbPacketResult SetUsbMode(byte mode)
        {
            ch.WriteCommand(SET_USB_MODE);
            ch.WriteData(mode);
            for(int i=0; i<50; i++)
            {
                if (ch.ReadData() == CMD_RET_SUCCESS)
                    return UsbPacketResult.Ok;

                Thread.Sleep(1);
            }

            return UsbPacketResult.OtherError;
        }

        private void SetHostWithoutSofMode()
        {
            ch.WriteCommand(SET_USB_MODE);
            ch.WriteData(5);
        }

        public UsbDeviceConnectionStatus CheckConnectionStatus()
        {
            if (ch.IntIsActive)
            {
                ch.WriteCommand(GET_STATUS);
                var status = ch.ReadData();

                if (status == INT_CONNECT)
                {
                    deviceIsConnected = true;
                    return BusResetAndSetHostWithSofMode() == UsbPacketResult.Ok ?
                        UsbDeviceConnectionStatus.Changed :
                        UsbDeviceConnectionStatus.Error;
                }
                else if (status == INT_DISCONNECT)
                {
                    deviceIsConnected = false;
                    SetHostWithoutSofMode();
                    return UsbDeviceConnectionStatus.NotConnected;
                }
            }

            return deviceIsConnected ? UsbDeviceConnectionStatus.Connected : UsbDeviceConnectionStatus.NotConnected;
        }

        public UsbTransferResult ExecuteControlTransfer(UsbSetupPacket setupPacket, byte[] dataBuffer, int dataBufferIndex, int deviceAddress, int endpointPacketSize, int endpointNumber = 0)
        {
            var toggle = 0;
            var requestedDataLength = (int)setupPacket.wLength;
            var remainingDataLength = requestedDataLength;
            UsbPacketResult result;

            SetTargetDeviceAddress(deviceAddress);

            //Setup

            WriteUsbData(setupPacket.ToByteArray());
            IssueToken(endpointNumber, PID_SETUP, 0, 0);
            if ((result = WaitAndGetResult()) != UsbPacketResult.Ok)
                return new UsbTransferResult(result);

            //Data

            var dataTransferResult = setupPacket.DataDirection == UsbDataDirection.IN ?
                ExecuteDataInTransfer(dataBuffer, dataBufferIndex, requestedDataLength, deviceAddress, 0, endpointPacketSize, 1) :
                ExecuteDataOutTransfer(dataBuffer, dataBufferIndex, requestedDataLength, deviceAddress, 0, endpointPacketSize, 1);

            if (dataTransferResult.IsError)
                return dataTransferResult;

            //Status

            if(setupPacket.DataDirection == UsbDataDirection.IN)
                result = RepeatWhileNak(() => {
                    WriteUsbData(noData);
                    IssueToken(endpointNumber, PID_OUT, 0, 1);
                });
            else
                result = RepeatWhileNak(() => {
                    IssueToken(endpointNumber, PID_IN, 1, 0);
                    ReadUsbData(null);
                });

            if (result != UsbPacketResult.Ok)
                return new UsbTransferResult(result);

            return dataTransferResult;
        }

        private UsbPacketResult RepeatWhileNak(Action action)
        {
            UsbPacketResult result;
            do
            {
                action();
                result = WaitAndGetResult();
                if (result == UsbPacketResult.Nak)
                    Thread.Sleep(1);
            }
            while (result == UsbPacketResult.Nak);
            return result;
        }

        private void SetTargetDeviceAddress(int deviceAddress)
        {
            ch.WriteCommand(SET_USB_ADDR);
            ch.WriteData((byte)deviceAddress);
        }

        private void WriteUsbData(byte[] data, int index = 0, int? length = null)
        {
            length = length ?? data.Length - index;
            ch.WriteCommand(WR_HOST_DATA);
            ch.WriteData((byte)length);
            for(var i = 0; i < length; i++)
                ch.WriteData(data[index + i]);
        }

        int ReadUsbData(byte[] data, int index = 0)
        {
            ch.WriteCommand(RD_USB_DATA0);
            var length = ch.ReadData();

            if (data != null)
            {
                var data2 = ch.ReadMultipleData(length);
                Array.Copy(data2, 0, data, index, length);
            }

            return length;
        }

        void IssueToken(int endpointNumber, byte pid, int intToggle, int outToggle)
        {
            ch.WriteCommand(ISSUE_TKN_X);
            ch.WriteData((byte)(intToggle << 7 | outToggle << 6));
            ch.WriteData((byte)(endpointNumber << 4 | pid));
        }

        private UsbPacketResult WaitAndGetResult()
        {
            while (!ch.IntIsActive)
                Thread.Sleep(1);

            ch.WriteCommand(GET_STATUS);
            var result = ch.ReadData();

            switch(result)
            {
                case CMD_RET_SUCCESS:
                    return UsbPacketResult.Ok;
                case INT_SUCCESS:
                    return UsbPacketResult.Ok;
                case INT_DISCONNECT:
                    deviceIsConnected = false;
                    SetHostWithoutSofMode();
                    return UsbPacketResult.NoDeviceConnected;
                case USB_INT_BUF_OVER:
                    return UsbPacketResult.DataError;
            }

            var result2 = result & 0x2F;

            switch(result2)
            {
                case 0x2A:
                    return UsbPacketResult.Nak;
                case 0x2E:
                    return UsbPacketResult.Stall;
            }

            result2 &= 0x23;

            if (result2 == 0x20)
                return UsbPacketResult.Timeout;

            throw new Exception($"Unexpected value from GET_STATUS: 0x{result:X}");
        }

        public UsbTransferResult ExecuteDataInTransfer(byte[] dataBuffer, int dataBufferIndex, int dataLength, int deviceAddress, int endpointNumber, int endpointPacketSize, int toggleBit)
        {
            var remainingDataLength = dataLength;
            UsbPacketResult result;

            SetTargetDeviceAddress(deviceAddress);

            while (remainingDataLength > 0)
            {
                result = RepeatWhileNak(() => IssueToken(endpointNumber, PID_IN, toggleBit, 0));
                if (result != UsbPacketResult.Ok)
                    return new UsbTransferResult(result, toggleBit);

                toggleBit = toggleBit ^ 1;
                var amountRead = ReadUsbData(dataBuffer, dataBufferIndex);
                dataBufferIndex += amountRead;
                remainingDataLength -= amountRead;

                if (amountRead < endpointPacketSize)
                    break;
            }

            return new UsbTransferResult(dataLength - remainingDataLength, toggleBit);
        }

        public UsbTransferResult ExecuteDataOutTransfer(byte[] dataBuffer, int dataBufferIndex, int dataLength, int deviceAddress, int endpointNumber, int endpointPacketSize, int toggleBit)
        {
            var remainingDataLength = dataLength;
            UsbPacketResult result;

            SetTargetDeviceAddress(deviceAddress);

            while (remainingDataLength > 0)
            {
                var amountWritten = Math.Min(endpointPacketSize, remainingDataLength);
                WriteUsbData(dataBuffer, dataBufferIndex, amountWritten);
                result = RepeatWhileNak(() => IssueToken(endpointNumber, PID_OUT, 0, toggleBit));
                if (result != UsbPacketResult.Ok)
                    return new UsbTransferResult(result, toggleBit);

                toggleBit = toggleBit ^ 1;
                dataBufferIndex += amountWritten;
                remainingDataLength -= amountWritten;
            }

            return new UsbTransferResult(dataLength, toggleBit);
        }

        public UsbTransferResult GetDescriptor(int deviceAddress, byte descriptorType, byte descriptorIndex, int languageId, out byte[] descriptorBytes)
        {
            SetTargetDeviceAddress(deviceAddress);

            descriptorBytes = null;
            if(
                (descriptorType != UsbDescriptorType.DEVICE && 
                descriptorType != UsbDescriptorType.CONFIGURATION) ||
                descriptorIndex != 0 ||
                languageId != 0)
            {
                return new UsbTransferResult(UsbPacketResult.NotImplemented);
            }

            ch.WriteCommand(GET_DESCR);
            ch.WriteCommand(descriptorType);
            var result = WaitAndGetResult();
            if (result == UsbPacketResult.DataError)
                return new UsbTransferResult(UsbPacketResult.NotImplemented);
            else if (result != UsbPacketResult.Ok)
                return new UsbTransferResult(result);

            descriptorBytes = new byte[64];
            var length = ReadUsbData(descriptorBytes);
            descriptorBytes = descriptorBytes.Take(length).ToArray();
            return new UsbTransferResult(length, 0);
        }
    }
}
