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

            HardwareReset();
            deviceIsConnected = false;
            SetHostWithoutSofMode();
        }

        bool deviceIsConnected = false;

        public void HardwareReset()
        {
            ch.WriteCommand(RESET_ALL);
            Thread.Sleep(50);
        }

        private void BusResetAndSetHostWithSofMode()
        {
            ch.WriteCommand(SET_USB_MODE);
            ch.WriteData(7);
            Thread.Sleep(1);
            var result = WaitAndGetResult(expectIntConnect: true);
            if (result != UsbPacketResult.Ok)
                throw new UsbTransferException($"When setting host mode without SOF: 0x{result:X}", result);

            ch.WriteCommand(SET_USB_MODE);
            ch.WriteData(6);
            Thread.Sleep(1);
            result = WaitAndGetResult(expectIntConnect: true);
            if (result != UsbPacketResult.Ok)
                throw new UsbTransferException($"When setting host mode with SOF: 0x{result:X}", result);
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
                    BusResetAndSetHostWithSofMode();
                    return UsbDeviceConnectionStatus.Changed;
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

            if (setupPacket.DataDirection == UsbDataDirection.OUT && requestedDataLength > 0)
                throw new NotImplementedException("Control OUT transactions are not implemented yet");

            SetTargetDeviceAddress(deviceAddress);

            //Setup

            WriteUsbData(setupPacket.ToByteArray());
            IssueToken(endpointNumber, PID_SETUP, 0, 0);
            if ((result = WaitAndGetResult()) != UsbPacketResult.Ok)
                return new UsbTransferResult(result);

            Thread.Sleep(1);

            //Data

            while (remainingDataLength > 0)
            {
                toggle = toggle ^ 1;
                result = RepeatWhileNak(() => IssueToken(endpointNumber, PID_IN, toggle, 0));
                if (result != UsbPacketResult.Ok)
                    return new UsbTransferResult(result);

                var amountRead = ReadUsbData(dataBuffer, dataBufferIndex);
                dataBufferIndex += amountRead;
                remainingDataLength -= amountRead;

                if (amountRead < endpointPacketSize)
                    break;
            }

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

            return new UsbTransferResult(requestedDataLength - remainingDataLength, 0);
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
            ch.WriteCommand((byte)deviceAddress);
        }

        private void WriteUsbData(byte[] data)
        {
            ch.WriteCommand(WR_HOST_DATA);
            ch.WriteData((byte)data.Length);
            foreach (var b in data)
                ch.WriteData(b);
        }

        int ReadUsbData(byte[] data, int index = 0)
        {
            ch.WriteCommand(RD_USB_DATA0);
            var length = ch.ReadData();
            if(data != null)
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

        private UsbPacketResult WaitAndGetResult(bool expectIntConnect = false)
        {
            var waited = 0;
            while (!ch.IntIsActive && waited++ < 10) Thread.Sleep(1);
            ch.WriteCommand(GET_STATUS);
            var result = ch.ReadData();

            if (result == INT_CONNECT && expectIntConnect)
                return UsbPacketResult.Ok;

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
