/*
The "Noobtocol": A very simple protocol for communication with a CH376
connected to the Arduino using parallel interface.

The protocol is as follows:

- To write to the command port:
  Host sends 1, then the command byte.

- To read the status port:
  Host sends 2, then reads the status byte.

- To write to the data port:
  Host sends 3, then the data byte.

- To read from the data port:
  Host sends 4, then reads the data byte.
*/

/*
By Konamiman, extending original code by Xavirompe
*/

const unsigned long SERIAL_BAUDS = 115200;

//CH376 pins to Arduino digital connections mapping

const int CH_RD = 3;
const int CH_WR = 4;
const int CH_PCS = A0;
const int CH_A0 = 13;
const int CH_INT = 2;
const int CH_D0 = 5;
//CH_Dx = CH_D0 + x

const int CH_A0_DATA = LOW;
const int CH_A0_COMMAND = HIGH;

void setup() {
	pinMode(CH_RD, OUTPUT);
	pinMode(CH_WR, OUTPUT);
	pinMode(CH_PCS, OUTPUT);
	pinMode(CH_A0, OUTPUT);
	
	digitalWrite(CH_PCS, HIGH);
	digitalWrite(CH_RD, HIGH);
	digitalWrite(CH_WR, HIGH);

	Serial.begin(SERIAL_BAUDS);
}

void loop() {
	byte data;

	if (Serial.available() == 0) return;

	data = ReadByteFromSerial();
	switch (data)
	{
	case 1: //Write command
		data = ReadByteFromSerial();
		CH_WriteCommand(data);
		break;
	case 2: //Read status
		data = CH_ReadStatus();
		WriteByteToSerial(data);
		break;
	case 3: //Write data
		data = ReadByteFromSerial();
		CH_WriteData(data);
		break;
	case 4: //Read data
		data = CH_ReadData();
		WriteByteToSerial(data);
		break;
	default:
		while (Serial.available() >= 0) Serial.read();
	}

	//while (Serial.available() >= 0) Serial.read();
}

byte ReadByteFromSerial()
{
	 while (Serial.available() == 0);
	 return Serial.read();
}

void WriteByteToSerial(byte data)
{
	while (Serial.availableForWrite() == 0);
	Serial.write(data);
	//Serial.flush();
}

byte CH_ReadData()
{
	return CH_ReadPort(CH_A0_DATA);
}

byte CH_ReadStatus()
{
	return CH_ReadPort(CH_A0_COMMAND);
}

byte CH_ReadPort(int address)
{
	byte data = 0;

	digitalWrite(CH_A0, address);

	for (int i = 0; i < 8; i++)
	{
		pinMode(CH_D0 + i, INPUT);
		digitalWrite(CH_D0 + i, LOW);
	}

	digitalWrite(CH_PCS, LOW);
	digitalWrite(CH_RD, LOW);

	for (int i = 0; i < 8; i++)
	{
		data >>= 1;
		data |= (digitalRead(CH_D0 + i) == HIGH) ? 128 : 0;
	}

	digitalWrite(CH_RD, HIGH);
	digitalWrite(CH_PCS, HIGH);

	return data;
}

byte CH_WritePort(int address, byte data)
{
	digitalWrite(CH_A0, address);

	for (int i = 0; i < 8; i++)
	{
		pinMode(CH_D0 + i, OUTPUT);
	}

	digitalWrite(CH_PCS, LOW);
	digitalWrite(CH_WR, LOW);
	
	for (int i = 0; i < 8; i++)
	{
		digitalWrite(CH_D0 + i, (((data >> i) & 1) == 0) ? LOW : HIGH);
	}

	digitalWrite(CH_WR, HIGH);
	digitalWrite(CH_PCS, HIGH);

	return data;
}

byte CH_WriteData(byte data)
{
	return CH_WritePort(CH_A0_DATA, data);
}

byte CH_WriteCommand(byte command)
{
	return CH_WritePort(CH_A0_COMMAND, command);
}
