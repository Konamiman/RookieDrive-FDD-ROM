using System;
using System.Threading;

namespace Konamiman.RookieDrive.Usb
{
    public class CH376UsbHostHardware : IUsbHostHardware
    {
        const byte RESET_ALL = 0x05;
        const byte WR_HOST_DATA = 0x2C;
        const byte RD_USB_DATA0 = 0x27;
        const byte ISSUE_TKN_X = 0x4E;
        const byte GET_STATUS = 0x22;
        const byte SET_USB_ADDR = 0x13;
        const byte SET_USB_MODE = 0x15;

        const byte PID_SETUP = 0x0D;
        const byte PID_IN = 0x09;
        const byte PID_OUT = 0x01;

        const byte INT_SUCCESS = 0x14;
        const byte INT_CONNECT = 0x15;
        const byte INT_DISCONNECT = 0x16;
        const byte USB_INT_BUF_OVER = 0x17;

        private readonly ICH376Ports ch;
        private static readonly byte[] noData = new byte[0];

        public CH376UsbHostHardware(ICH376Ports ch376Ports)
        {
            this.ch = ch376Ports;

            SetHostWithoutSofMode(); //Assume no device connected to start with
            HardwareReset();
        }

        bool deviceIsConnected = false;

        public void HardwareReset()
        {
            ch.WriteCommand(RESET_ALL);
            Thread.Sleep(35);

            UpdateConnectedDeviceStatus();
        }

        private void BusResetAndSetHostWithSofMode()
        {
            ch.WriteCommand(SET_USB_MODE);
            ch.WriteData(7);

            Thread.Sleep(1);

            ch.WriteCommand(SET_USB_MODE);
            ch.WriteData(6);
        }

        private void SetHostWithoutSofMode()
        {
            ch.WriteCommand(SET_USB_MODE);
            ch.WriteData(5);
        }

        public bool DeviceIsConnected()
        {
            UpdateConnectedDeviceStatus();
            return deviceIsConnected;
        }

        private void UpdateConnectedDeviceStatus()
        {
            if (!ch.IntIsActive)
                return;

            ch.WriteCommand(GET_STATUS);
            var status = ch.ReadData();

            if (status == INT_CONNECT)
            {
                deviceIsConnected = true;
                BusResetAndSetHostWithSofMode();
            }
            else if (status == INT_DISCONNECT)
            {
                deviceIsConnected = false;
                SetHostWithoutSofMode();
            }
        }

        public UsbTransferResult ExecuteControlTransfer(byte[] commandBytes, byte[] dataBuffer, int dataBufferIndex, int deviceAddress, int endpointPacketSize, int endpointNumber = 0)
        {
            var toggle = 0;
            var requestedDataLength = (int)BitConverter.ToInt16(commandBytes, 6);
            var remainingDataLength = requestedDataLength;
            UsbPacketResult result;

            if (commandBytes.Length != 8)
                throw new ArgumentException($"Length of {nameof(commandBytes)} must be 8");

            if ((commandBytes[0] & 0x80) == 0)
                throw new NotImplementedException("Control OUT transactions are not implemented yet");

            if (!DeviceIsConnected())
                return new UsbTransferResult(UsbPacketResult.NoDeviceConnected);

            SetTargetDeviceAddress(deviceAddress);

            //Setup

            WriteUsbData(commandBytes);
            IssueToken(endpointNumber, PID_SETUP, 0, 0);
            if ((result = WaitAndGetResult()) != UsbPacketResult.Ok)
                return new UsbTransferResult(result);

            //Data

            while (remainingDataLength > 0)
            {
                toggle = toggle ^ 1;
                IssueToken(endpointNumber, PID_IN, toggle, 0);
                if ((result = WaitAndGetResult()) != UsbPacketResult.Ok)
                    return new UsbTransferResult(result);

                var amountRead = ReadUsbData(dataBuffer, dataBufferIndex);
                dataBufferIndex += amountRead;
                remainingDataLength -= amountRead;

                if (amountRead < endpointPacketSize)
                    break;
            }

            //Status

            WriteUsbData(noData);
            IssueToken(endpointNumber, PID_OUT, 0, 1);
            if ((result = WaitAndGetResult()) != UsbPacketResult.Ok)
                return new UsbTransferResult(result);

            return new UsbTransferResult(requestedDataLength - remainingDataLength, 0);
        }

        private void SetTargetDeviceAddress(int deviceAddress)
        {
            ch.WriteCommand(SET_USB_ADDR);
            ch.WriteCommand((byte)deviceAddress);
        }

        private void WriteUsbData(byte[] data)
        {
            ch.WriteCommand(WR_HOST_DATA);
            ch.WriteData((byte)data.Length);
            foreach (var b in data)
                ch.WriteData(b);
        }

        int ReadUsbData(byte[] data, int index)
        {
            ch.WriteCommand(RD_USB_DATA0);
            var length = ch.ReadData();
            for (int i = 0; i < length; i++)
                data[index + i] = ch.ReadData();

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
            while (!ch.IntIsActive) Thread.Sleep(1);
            ch.WriteCommand(GET_STATUS);
            var result = ch.ReadData();

            switch(result)
            {
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
            throw new NotImplementedException();
        }

        public UsbTransferResult ExecuteDataOutTransfer(byte[] dataBuffer, int dataBufferIndex, int dataLength, int deviceAddress, int endpointNumber, int endpointPacketSize, int toggleBit)
        {
            throw new NotImplementedException();
        }
    }
}
