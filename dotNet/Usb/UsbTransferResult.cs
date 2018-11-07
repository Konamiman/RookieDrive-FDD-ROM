using System;

namespace Konamiman.RookieDrive.Usb
{
    public class UsbTransferResult
    {
        public UsbTransferResult(UsbPacketResult transactionResult, int nextToggleBit = 0)
        {
            this.TransactionResult = transactionResult;
            this.TransferredDataCount = 0;
            this.NextTogleBit = nextToggleBit;
        }

        public UsbTransferResult(int transferredDataCount, int nextToggleBit)
        {
            if (nextToggleBit != 0 && nextToggleBit != 1)
                throw new ArgumentException($"{nameof(nextToggleBit)} must be either 0 or 1");

            this.TransactionResult = UsbPacketResult.Ok;
            this.TransferredDataCount = transferredDataCount;
            this.NextTogleBit = nextToggleBit;
        }

        public UsbPacketResult TransactionResult { get; }

        public int TransferredDataCount { get; }

        public int NextTogleBit { get; }

        public bool IsError => TransactionResult != UsbPacketResult.Ok;

        public bool IsStallError => TransactionResult == UsbPacketResult.Stall;

        public bool IsErrorButNotStall => IsError && !IsStallError;
    }
}
