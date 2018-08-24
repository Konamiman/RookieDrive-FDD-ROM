namespace Konamiman.RookieDrive.Usb
{
    public class UsbCbiCommandResult
    {
        public UsbCbiCommandResult(UsbPacketResult transactionResult, int transferredDataCount, byte[] senseData)
        {
            this.TransactionResult = transactionResult;
            this.SenseData = senseData;
            this.TransferredDataCount = transferredDataCount;
        }

        public byte[] SenseData { get; }

        public UsbPacketResult TransactionResult { get; }

        public int TransferredDataCount { get; }

        public bool IsError => TransactionResult != UsbPacketResult.Ok;
    }
}
