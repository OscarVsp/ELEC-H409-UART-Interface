import sys
import time
import serial
import glob
from typing import List

TITLE = """
  _____ _     _____ ____      _   _       _  _    ___   ___  
 | ____| |   | ____/ ___|    | | | |     | || |  / _ \ / _ \ 
 |  _| | |   |  _|| |   _____| |_| |_____| || |_| | | | (_) |
 | |___| |___| |__| |__|_____|  _  |_____|__   _| |_| |\__, |
 |_____|_____|_____\____|    |_| |_|        |_|  \___/   /_/
           _   ___ ___   ___          _        _   
          /_\ | __/ __| | _ \_ _ ___ (_)___ __| |_ 
         / _ \| _|\__ \ |  _/ '_/ _ \| / -_) _|  _|
        /_/ \_\___|___/ |_| |_| \___// \___\__|\__|
                                   |__/           
"""

def serial_ports() -> List[str]:
    """ Lists serial port names

        :raises EnvironmentError:
            On unsupported or unknown platforms
        :returns:
            A list of the serial ports available on the system
    """
    if sys.platform.startswith('win'):
        ports = ['COM%s' % (i + 1) for i in range(256)]
    elif sys.platform.startswith('linux') or sys.platform.startswith('cygwin'):
        # this excludes your current terminal "/dev/tty"
        ports = glob.glob('/dev/tty[A-Za-z]*')
    elif sys.platform.startswith('darwin'):
        ports = glob.glob('/dev/tty.*')
    else:
        raise EnvironmentError('Unsupported platform')

    result = []
    for port in ports:
        try:
            s = serial.Serial(port)
            s.close()
            result.append(port)
        except (OSError, serial.SerialException):
            pass
    return result

def serial_port_menu() -> str:
    available_ports = serial_ports()
    
    while len(available_ports) == 0:
        input("No serial port available. Make sure to connect to device then press enter to try again")
        available_ports = serial_ports()
    while True:
        print("Choose a serial port:")
        for i, port in enumerate(available_ports):
            print(f"    ({i}) {port}")
        try:
            resp = int(input(""))
        except ValueError:
            print("Wrong reponse type, try again !")
        else:
            try:
                port = available_ports[resp]
                return port
            except IndexError:
                print(f"{resp} is out of range, try again !")
                
def baudrate_menu() -> str:
    while True:
        print("Choose a baudrate (leave empty for 230400 by default):")
        try:
            resp = input("")
            if resp == "":
                resp = 230400
            else:
                resp = int(resp)
        except ValueError:
            print("Wrong reponse type, try again !")
        else:
            return resp
        
def divide_chunks(data: bytes, chunk_size: int) -> List[bytes]:
    chunks = []
    for i in range(0, len(data), chunk_size): 
        chunks.append(data[i:i + chunk_size])
    return chunks
        
def write_chunk(chunk: bytes, port: str, baudrate: int):
    with serial.Serial(port, baudrate) as ser:
        time.sleep(0.1)
        for i in range(len(chunk)):
            ser.write(chunk[i])
        for _ in range(i+1, 16):
            ser.write(b'0')
            
def read_chunk(port: str, baudrate: int) -> bytes:
    with serial.Serial(port, baudrate) as ser:
        time.sleep(0.1)
        chunk = ser.read(size=16)
    return chunk


if __name__ == "__main__":
    
    print(TITLE)

    port = serial_port_menu()
    print("\n")
    baudrate = baudrate_menu()
    print("\n")
    print("\n")

    while True:
        input_text = str(input("Text to send ?\n"))
        input_bytes = input_text.encode()
        print(f"Encoded text: {input_bytes.hex()}")
        input_chunks = divide_chunks(input_bytes, 16)
        print(f"{len(input_chunks)} chunk(s) to send")
        output_chunks: List[bytes] = []
        for i,current_chunk in enumerate(input_chunks):
            print(f"Sending chunk {i}: {current_chunk.hex()}", end=" -> ")
            write_chunk(current_chunk, port, baudrate)
            current_chunk = read_chunk(port, baudrate)
            output_chunks.append(current_chunk)
            print(f"{current_chunk.hex()}")
        output_text = "".join([b.decode() for b in output_chunks])[:len(input_text)]
        print(f'Output text:\n"{output_text}"')
        print("\n\n")